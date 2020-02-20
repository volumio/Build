#!/bin/bash

# This script will be run in chroot under qemu.

set -eo pipefail
# Reimport helpers in chroot
# shellcheck source=./scripts/helpers.sh
source /helpers.sh

function exit_error()
{
  log "Volumio chroot config failed" "$(basename "$0")" "err"
}

trap exit_error INT ERR

check_dependency() {
  dpkg -l $1 &> /dev/null
  if [ $? -eq 0 ]; then
    echo "${1} installed"
    # print something saying it is installed
  else
    echo "${1} not installed"
    # print something saying it was not found
  fi
}

NODE_VERSION=node_8.x
DISTRO_VER="$(lsb_release -s -r)"
DISTRO_NAME="$(lsb_release -s -c)"

log "Preapring to run Debconf in chroot" "info"
log "Prevent services starting during install, running under chroot"
cat <<-EOF > /usr/sbin/policy-rc.d
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

log "Configuring dpkg to not include Manual pages and docs"
cat <<-EOF > /etc/bash.bashrc
path-exclude /usr/share/doc/*
# we need to keep copyright files for legal reasons
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
# lintian stuff is small, but really unnecessary
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*"
EOF


export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

log "Running dpkg fixes for ${DISTRO_NAME}(${DISTRO_VER})"
if [[  ${DISTRO_VER} = 10 ]]; then
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=924401
  log "Running base-passwd.preinst" "wrn"
  /var/lib/dpkg/info/base-passwd.preinst install
else
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=890073
  /var/lib/dpkg/info/dash.preinst install
fi

log "Configuring packages" "info"
#TODO do we need to log full output
# shellcheck disable=SC2069
if ! dpkg --configure --pending  2>&1 > /dpkg.log
# if ! { dpkg --configure -a  > /dev/null; } 2>&1
then
  log "Failed configuring packages!" "err"
else
  log "Finished configuring packages" "okay"
fi

#Reduce locales to just one beyond C.UTF-8
log "Prepare Volumio Debain customization" "info"
log "Existing locales: " && locale -a

# Enable LANG_def='en_US.UTF-8'
[[ -f /etc/locale.gen ]] && \
    sed -i "s/^# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
locale-gen
update-locale LANG=en_US:en LC_ALL=en_US.UTF-8

log "Final locale list"
locale -a


#Adding Main user Volumio
log "Adding Volumio User"
groupadd volumio
useradd -c volumio -d /home/volumio -m -g volumio -G adm,dialout,cdrom,floppy,audio,dip,video,plugdev,netdev,lp -s /bin/bash -p '$6$tRtTtICB$Ki6z.DGyFRopSDJmLUcf3o2P2K8vr5QxRx5yk3lorDrWUhH64GKotIeYSNKefcniSVNcGHlFxZOqLM6xiDa.M.' volumio

#Setting Root Password
# echo 'root:$1$JVNbxLRo$pNn5AmZxwRtWZ.xF.8xUq/' | chpasswd -e

#Global BashRC Aliases"
log 'Setting BashRC for custom system calls'
cat <<-EOF > /etc/bash.bashrc
## System Commands ##
alias reboot="sudo /sbin/reboot"
alias poweroff="sudo /sbin/poweroff"
alias halt="sudo /sbin/halt"
alias shutdown="sudo /sbin/shutdown"
alias apt-get="sudo /usr/bin/apt-get"
alias systemctl="/bin/systemctl"
alias iwconfig="iwconfig wlan0"
alias come="echo 'se fosse antani'"
## Utilities thanks to http://www.cyberciti.biz/tips/bash-aliases-mac-centos-linux-unix.html ##
## Colorize the ls output ##
alias ls="ls --color=auto"
## Use a long listing format ##
alias ll="ls -la"
## Show hidden files ##
alias l.="ls -d .* --color=auto"
## get rid of command not found ##
alias cd..="cd .."
## a quick way to get out of current directory ##
alias ..="cd .."
alias ...="cd ../../../"
alias ....="cd ../../../../"
alias .....="cd ../../../../"
alias .4="cd ../../../../"
alias .5="cd ../../../../.."
# install with apt-get
alias updatey="sudo apt-get --yes"
## Read Like humans ##
alias df="df -H"
alias du="du -ch"
alias makemeasandwich="echo 'What? Make it yourself'"
alias sudomakemeasandwich="echo 'OKAY'"
alias snapclient="/usr/sbin/snapclient"
alias snapserver="/usr/sbin/snapserver"
alias mount="sudo /bin/mount"
alias systemctl="sudo /bin/systemctl"
alias killall="sudo /usr/bin/killall"
alias service="sudo /usr/sbin/service"
alias ifconfig="sudo /sbin/ifconfig"
# tv-service
alias tvservice="/opt/vc/bin/tvservice"
# vcgencmd
alias vcgencmd="/opt/vc/bin/vcgencmd"
EOF

#Sudoers Nopasswd
SUDOERS_FILE="/etc/sudoers.d/volumio-user"
log 'Adding Safe Sudoers NoPassw permissions'
cat <<-EOF > ${SUDOERS_FILE}
# Add permissions for volumio user
volumio ALL=(ALL) ALL
volumio ALL=(ALL) NOPASSWD: /sbin/poweroff,/sbin/shutdown,/sbin/reboot,/sbin/halt,/bin/systemctl,/usr/bin/apt-get,/usr/sbin/update-rc.d,/usr/bin/gpio,/bin/mount,/bin/umount,/sbin/iwconfig,/sbin/iwlist,/sbin/ifconfig,/usr/bin/killall,/bin/ip,/usr/sbin/service,/etc/init.d/netplug,/bin/journalctl,/bin/chmod,/sbin/ethtool,/usr/sbin/alsactl,/bin/tar,/usr/bin/dtoverlay,/sbin/dhclient,/usr/sbin/i2cdetect,/sbin/dhcpcd,/usr/bin/alsactl,/bin/mv,/sbin/iw,/bin/hostname,/sbin/modprobe,/sbin/iwgetid,/bin/ln,/usr/bin/unlink,/bin/dd,/usr/bin/dcfldd,/opt/vc/bin/vcgencmd,/opt/vc/bin/tvservice,/usr/bin/renice,/bin/rm
volumio ALL=(ALL) NOPASSWD: /bin/sh /volumio/app/plugins/system_controller/volumio_command_line_client/commands/kernelsource.sh, /bin/sh /volumio/app/plugins/system_controller/volumio_command_line_client/commands/pull.sh
EOF
chmod 0440 ${SUDOERS_FILE}


log "Setting up hostname"
echo volumio > /etc/hostname
chmod 777 /etc/hostname
chmod 777 /etc/hosts

echo "nameserver 8.8.8.8" > /etc/resolv.conf


log "Testing curl" "dbg"
curl -LS 'https://github.com/' -o /dev/null || log "SSL issues" "wrn"  && CURLFAIL=yes
# Took a while to debug this -
# export DEB_BUILD_MAINT_OPTIONS = hardening=+all future=+lfs
#https://sourceware.org/bugzilla/show_bug.cgi?id=23960
[[ $CURLFAIL == yes ]] && log "Fixing ca-certificates" "wrn" && c_rehash

################
#Volumio System#---------------------------------------------------
################
log "Setting up Volumio system structure and permissions" "info"
log "Setting proper ownership"
chown -R volumio:volumio /volumio

log "Creating Data Path"
mkdir /data
chown -R volumio:volumio /data

log "Creating ImgPart Path"
mkdir /imgpart
chown -R volumio:volumio /imgpart

log "Changing os-release permissions"
chown volumio:volumio /etc/os-release
chmod 777 /etc/os-release

log "Setting proper permissions for ping"
chmod u+s /bin/ping

log "Creating Volumio Folder Structure"
# Media Mount Folders
mkdir -p /mnt/NAS
mkdir -p /media
ln -s /media /mnt/USB

#Internal Storage Folder
mkdir /data/INTERNAL
ln -s /data/INTERNAL /mnt/INTERNAL

#UPNP Folder
mkdir /mnt/UPNP

#Permissions
chmod -R 777 /mnt
chmod -R 777 /media
chmod -R 777 /data/INTERNAL

################
#Volumio Package installation #---------------------------------------------------
################

ARCH=$(cat /etc/os-release | grep ^VOLUMIO_ARCH | tr -d 'VOLUMIO_ARCH="')
log "Installing custom packages for ${ARCH} and ${DISTRO_VER}" "info"
cd /

log "Prepare external source lists"
cat <<-EOF > /etc/apt/sources.list.d/nodesource.list
deb https://deb.nodesource.com/$NODE_VERSION $DISTRO_NAME main
deb-src https://deb.nodesource.com/$NODE_VERSION $DISTRO_NAME main
EOF

apt-get update
apt-get -y install nodejs

#TODO: Refactor this!
# Binaries
# Nodejs
# MPD,Upmpdcli
# Shairport-Sync, Shairport-Sync Metadata Reader
# volumio-remote-updater, Volumio Init Updater
# Snapcast, Zsync
# hostapd-edimax
# LINN Songcast - sc2mpd
# Node modules!

log "Cleaning up after package(s) installation"
apt-get clean
rm -rf tmp/*


log "Setting up MPD" "info"
# Symlinking Mount Folders to Mpd's Folder
ln -s /mnt/NAS /var/lib/mpd/music
ln -s /mnt/USB /var/lib/mpd/music
ln -s /mnt/INTERNAL /var/lib/mpd/music

# MPD configuration
log "Prepping MPD environment"
touch /var/lib/mpd/tag_cache
chmod 777 /var/lib/mpd/tag_cache
chmod 777 /var/lib/mpd/playlists

log "Setting mpdignore file"
cat <<-EOF > /var/lib/mpd/music/.mpdignore
@Recycle
#recycle
$*
System Volume Information
$RECYCLE.BIN
RECYCLER
EOF

log "Setting mpc to bind to unix socket"
export MPD_HOST=/run/mpd/socket

log "Setting Permissions for /etc/modules"
chmod 777 /etc/modules

log "Setting up services.." "info"
log "Adding Volumio Parent Service to Startup"
#systemctl enable volumio.service
ln -s /lib/systemd/system/volumio.service /etc/systemd/system/multi-user.target.wants/volumio.service

log "Adding First start script"
ln -s /lib/systemd/system/firststart.service /etc/systemd/system/multi-user.target.wants/firststart.service

log "Adding Dynamic Swap Service"
ln -s /lib/systemd/system/dynamicswap.service /etc/systemd/system/multi-user.target.wants/dynamicswap.service

log "Adding Iptables Service"
ln -s /lib/systemd/system/iptables.service /etc/systemd/system/multi-user.target.wants/iptables.service

log "Disabling SSH by default"
systemctl disable ssh.service

log "Enable Volumio SSH enabler"
ln -s /lib/systemd/system/volumiossh.service /etc/systemd/system/multi-user.target.wants/volumiossh.service

log "Setting Mpd to SystemD instead of Init"
update-rc.d mpd remove
systemctl enable mpd.service

log "Preventing hotspot services from starting at boot"
systemctl disable hotspot.service
systemctl disable dnsmasq.service

log "Preventing un-needed dhcp servers to start automatically"
systemctl disable isc-dhcp-server.service
systemctl disable dhcpd.service

log "Linking Volumio Command Line Client"
ln -s /volumio/app/plugins/system_controller/volumio_command_line_client/volumio.sh /usr/local/bin/volumio
chmod a+x /usr/local/bin/volumio

#####################
#Audio Optimizations#-----------------------------------------
#####################

log "Enabling Volumio optimizations" "info"
log "Adding Users to Audio Group"
usermod -a -G audio volumio
usermod -a -G audio mpd

log "Setting RT Priority to Audio Group"
echo '@audio - rtprio 99
@audio - memlock unlimited' >> /etc/security/limits.conf

log "Alsa tuning"
log "Creating Alsa state file"
touch /var/lib/alsa/asound.state
echo '#' > /var/lib/alsa/asound.state
chmod 777 /var/lib/alsa/asound.state

# echo "Fixing UPNP L16 Playback issue"
# grep -v '^@ENABLEL16' /usr/share/upmpdcli/protocolinfo.txt > /usr/share/upmpdcli/protocolinfo.txtrepl && mv /usr/share/upmpdcli/protocolinfo.txtrepl /usr/share/upmpdcli/protocolinfo.txt

#####################
#Network Settings and Optimizations#-----------------------------------------
#####################
log "Network Optimizations" "info"
log "Tuning LAN"
echo 'fs.inotify.max_user_watches = 524288' >> /etc/sysctl.conf

log "Disabling IPV6"
cat <<-EOF >> /etc/sysctl.conf
#disable ipv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

log "Creating Wireless service"
ln -s /lib/systemd/system/wireless.service /etc/systemd/system/multi-user.target.wants/wireless.service

log "Configuring hostapd"
cat <<-EOF >> /etc/hostapd/hostapd.conf
interface=wlan0
ssid=Volumio
channel=4
driver=nl80211
hw_mode=g
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=volumio2
EOF

cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.tmpl
chmod -R 777 /etc/hostapd

log "Empty resolv.conf.head for custom DNS settings"
touch /etc/resolv.conf.head

log "Setting fallback DNS with OpenDNS nameservers"
cat <<-EOF > /etc/resolv.conf.tail.tmpl
# OpenDNS nameservers
nameserver 208.67.222.222
nameserver 208.67.220.220" >
chmod 666 /etc/resolv.conf.*
EOF

ln -s /etc/resolv.conf.tail.tmpl /etc/resolv.conf.tail

log "Removing Avahi Service for UDISK-SSH"
rm -f /etc/avahi/services/udisks.service

#####################
#CPU  Optimizations#-----------------------------------------
#####################

log "Setting CPU governor to performance" "info"
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils

#####################
#Multimedia Keys#-----------------------------------------
#####################

log "Configuring xbindkeys"
cat <<-EOF > /etc/xbindkeysrc
"/usr/local/bin/volumio toggle"
    XF86AudioPlay
"/usr/local/bin/volumio previous"
    XF86AudioPrev
"/usr/local/bin/volumio next"
    XF86AudioNext
"/usr/local/bin/volumio volume toggle"
    XF86AudioMute
"/usr/local/bin/volumio volume minus"
    XF86AudioLowerVolume
"/usr/local/bin/volumio volume plus"
XF86AudioRaiseVolume'
EOF


log "Enabling xbindkeys"
ln -s /lib/systemd/system/xbindkeysrc.service /etc/systemd/system/multi-user.target.wants/xbindkeysrc.service


log "Finished Volumio chroot configuration for ${DISTRO_NAME}" "okay"
