#!/bin/bash

# This script will be run in chroot under qemu.

set -eo pipefail
# Reimport helpers in chroot
# shellcheck source=./scripts/helpers.sh
source /helpers.sh
CHROOT=yes
export CHROOT

function exit_error() {
  log "Volumio chroot config failed" "$(basename "$0")" "err"
}

trap exit_error INT ERR

check_dependency() {
  if ! dpkg -l "$1" &>/dev/null; then
    log "${1} installed"
  else
    log "${1} not installed"
  fi
}

DISTRO_VER="$(lsb_release -s -r)"
DISTRO_NAME="$(lsb_release -s -c)"

# Packages to install that are not in multistrap for some reason.
packages=nodejs

log "Preparing to run Debconf in chroot" "info"
# Not required, we have mounted /proc, systemd will be smart enough
# log "Prevent services starting during install, running under chroot"
# cat <<-EOF >/usr/sbin/policy-rc.d
# exit 101
# EOF
# chmod +x /usr/sbin/policy-rc.d

log "Configuring dpkg to not include Manual pages and docs"
cat <<-EOF >/etc/bash.bashrc
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
if [[ ${DISTRO_VER} = 10 ]]; then
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=924401
  log "Running base-passwd.preinst" "wrn"
  /var/lib/dpkg/info/base-passwd.preinst install
else
  # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=890073
  /var/lib/dpkg/info/dash.preinst install
fi

log "Configuring packages, this may take some time.." "info"
start_dpkg_configure=$(date +%s)
#TODO do we need to log full output
# shellcheck disable=SC2069
if ! dpkg --configure --pending 2>&1 >/dpkg.log; then # if ! { dpkg --configure -a  > /dev/null; } 2>&1
  log "Failed configuring packages!" "err"
else
  end_dpkg_configure=$(date +%s)
  time_it "$end_dpkg_configure" "$start_dpkg_configure"
  log "Finished configuring packages" "okay" "$TIME_STR"
fi

#Reduce locales to just one beyond C.UTF-8
log "Prepare Volumio Debian customization" "info"
log "Existing locales: " "" "$(locale -a | tr '\n' ' ')"

# Enable LANG_def='en_US.UTF-8'
[[ -e /etc/locale.gen ]] &&
  sed -i "s/^# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8
log "Final locale list: " "" "$(locale -a | tr '\n' ' ')"

#Adding Main user Volumio
log "Adding Volumio User"
groupadd volumio
# shellcheck disable=SC2016
useradd -c volumio -d /home/volumio -m -g volumio -G adm,dialout,cdrom,floppy,audio,dip,video,plugdev,netdev,lp -s /bin/bash -p '$6$tRtTtICB$Ki6z.DGyFRopSDJmLUcf3o2P2K8vr5QxRx5yk3lorDrWUhH64GKotIeYSNKefcniSVNcGHlFxZOqLM6xiDa.M.' volumio

#Setting Root Password
# shellcheck disable=SC2016
echo 'root:$1$JVNbxLRo$pNn5AmZxwRtWZ.xF.8xUq/' | chpasswd -e

#Global BashRC Aliases"
log 'Setting BashRC for custom system calls'
cat <<-EOF >/etc/bash.bashrc
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
EOF

#Sudoers Nopasswd
SUDOERS_FILE="/etc/sudoers.d/volumio-user"
log 'Adding Safe Sudoers NoPassw permissions'
cat <<-EOF >${SUDOERS_FILE}
# Add permissions for volumio user
volumio ALL=(ALL) ALL
volumio ALL=(ALL) NOPASSWD: /sbin/poweroff,/sbin/shutdown,/sbin/reboot,/sbin/halt,/bin/systemctl,/usr/bin/apt-get,/usr/sbin/update-rc.d,/usr/bin/gpio,/bin/mount,/bin/umount,/sbin/iwconfig,/sbin/iwlist,/sbin/ifconfig,/usr/bin/killall,/bin/ip,/usr/sbin/service,/etc/init.d/netplug,/bin/journalctl,/bin/chmod,/sbin/ethtool,/usr/sbin/alsactl,/bin/tar,/usr/bin/dtoverlay,/sbin/dhclient,/usr/sbin/i2cdetect,/sbin/dhcpcd,/usr/bin/alsactl,/bin/mv,/sbin/iw,/bin/hostname,/sbin/modprobe,/sbin/iwgetid,/bin/ln,/usr/bin/unlink,/bin/dd,/usr/bin/dcfldd,/opt/vc/bin/vcgencmd,/opt/vc/bin/tvservice,/usr/bin/renice,/bin/rm
volumio ALL=(ALL) NOPASSWD: /bin/sh /volumio/app/plugins/system_controller/volumio_command_line_client/commands/kernelsource.sh, /bin/sh /volumio/app/plugins/system_controller/volumio_command_line_client/commands/pull.sh
EOF
chmod 0440 ${SUDOERS_FILE}

# Fix qmeu 64 bit host issues for 32bit binaries on buster
# TODO: This is just one manifestation of the underlying error,
# probably safer to use 32bit qmeu
log "Testing for SSL issues" "dbg"
curl -LS 'https://github.com/' -o /dev/null || CURLFAIL=yes
log " SSL Issues: ${CURLFAIL:-no}"
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

# shellcheck source=/dev/null
source /etc/os-release

#TODO: Refactor this!
# Binaries
# MPD,Upmpdcli
# Shairport-Sync, Shairport-Sync Metadata Reader
# volumio-remote-updater, Volumio Init Updater
# Snapcast, Zsync
# hostapd-edimax
# LINN Songcast - sc2mpd
# Node modules!

# TODO: Think about restructuring this, copy all bits into rootfs first?
log "Setting up nameserver for apt resolution" "dbg"
echo "nameserver 208.67.220.220" >/etc/resolv.conf

log "Installing custom packages for ${VOLUMIO_ARCH} and ${DISTRO_VER}" "info"
log "Prepare external source lists"
log "Attempting to install Node version: ${NODE_VERSION}"
IFS=\. read -ra NODE_SEMVER <<<"$NODE_VERSION"
NODE_APT=node_${NODE_SEMVER[0]}.x
log "Adding NodeJs lists - ${NODE_APT}"
cat <<-EOF >/etc/apt/sources.list.d/nodesource.list
deb https://deb.nodesource.com/$NODE_APT $DISTRO_NAME main
deb-src https://deb.nodesource.com/$NODE_APT $DISTRO_NAME main
EOF

apt-get update
apt-get -y install $packages

log "Node $(node --version) arm_version: $(node <<<'console.log(process.config.variables.arm_version)')" "info"
log "nodejs installed at $(command -v node)" "info"

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
cat <<-EOF >/var/lib/mpd/music/.mpdignore
@Recycle
#recycle
$*
System Volume Information
$RECYCLE.BIN
RECYCLER
EOF

# This is not going to work
log "Setting mpc to bind to unix socket"
export MPD_HOST=/run/mpd/socket

log "Setting Permissions for /etc/modules"
chmod 777 /etc/modules

log "Setting up services.." "info"
#https://wiki.archlinux.org/index.php/Systemd#Writing_unit_files
#TODO: These should be in /etc/systemd/system/
# This won't work as the files are copied over only later in `configure.sh`
# mv /lib/systemd/system/volumio.service /etc/systemd/system/
# mv /lib/systemd/system/volumiossh.service /etc/systemd/system/
# So create empty symlinks now and place the files there later.

# log "Enable Volumio SSH enabler"
# systemctl --no-reload enable volumiossh

# log "Enable headless_wireless"
# systemctl enable headless_wireless

log "Adding Volumio Parent Service to Startup"
ln -s /lib/systemd/system/volumio.service /etc/systemd/system/multi-user.target.wants/volumio.service

log "Adding First start script"
ln -s /lib/systemd/system/firststart.service /etc/systemd/system/multi-user.target.wants/firststart.service

log "Adding Dynamic Swap Service"
ln -s /lib/systemd/system/dynamicswap.service /etc/systemd/system/multi-user.target.wants/dynamicswap.service

log "Adding Iptables Service"
ln -s /lib/systemd/system/iptables.service /etc/systemd/system/multi-user.target.wants/iptables.service

log "Adding headless_wireless Service"
ln -s /lib/systemd/system/headless_wireless.service /etc/systemd/system/multi-user.target.wants/headless_wireless.service

log "Disabling SSH by default"
systemctl disable ssh.service

log "Enable Volumio SSH enabler"
ln -s /lib/systemd/system/volumiossh.service /etc/systemd/system/multi-user.target.wants/volumiossh.service

log "Setting Mpd to SystemD instead of Init"
update-rc.d mpd remove
systemctl enable mpd.service

log "Preventing hotspot (hostapd/dnsmasq) services from starting at boot"
systemctl disable hostapd.service
systemctl disable dnsmasq.service

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
cat <<-EOF >>/etc/security/limits.conf
@audio - rtprio 99
@audio - memlock unlimited
EOF

log "Alsa Optimizations" "info"
log "Creating Alsa state file"
cat <<-EOF >/var/lib/alsa/asound.state
#
EOF
chmod 777 /var/lib/alsa/asound.state

log "Setting USB DAC ordering"
## Set USB card ordering
#https://alsa.opensrc.org/Usb-audio
cat <<-EOF >>/etc/modprobe.d/alsa-base.conf
#Tuning USB devices for minimal latencies
options snd-usb-audio nrpacks=1
# USB DACs will have device number 5 in whole Volumio device range
options snd-usb-audio index=5
EOF

#####################
#Network Settings and Optimizations#-----------------------------------------
#####################
log "Network settings and optimizations" "info"
# log "Setting up networking defaults" "info"

log "Set default hostname to volumio"
cat <<-EOF >/etc/hosts
127.0.0.1       localhost
127.0.1.1       volumio

# The following lines are desirable for IPv6 capable hosts
::1             localhost volumio ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF
echo volumio >/etc/hostname
chmod 777 /etc/hostname
chmod 777 /etc/hosts

log "Creating an empty dhcpd.leases if required"
lease_file="/var/lib/dhcp/dhcpd.leases"
[[ ! -f $lease_file ]] && mkdir -p "$(dirname $lease_file)" && touch $lease_file

log "Disabling IPV6, increasing inotify watchers"
cat <<-EOF >>/etc/sysctl.conf
# Increase inotify watchers
fs.inotify.max_user_watches = 524288
#disable ipv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

log "Creating Wireless service"
ln -s /lib/systemd/system/wireless.service /etc/systemd/system/multi-user.target.wants/wireless.service
log "Setting up wireless hostspot config" "info"
# Fix dnsmasq service
log "Adding Volumio bits to dnsmasq and hostapd services"
sed -i '/^After=network.target/a # For Volumio hotspot functionality\nAfter=hostapd.service\nPartOf=hostapd.service' /lib/systemd/system/dnsmasq.service
sed -i '/^After=network.target/a # For Volumio hotspot functionality\nWants=dnsmasq.service' /lib/systemd/system/hostapd.service

log "Configuring dnsmasq"
# TODO listen on wlan* or only wlan0?
cat <<-EOF >>/etc/dnsmasq.d/hotspot.conf
# dnsmasq hotspot configuration for Volumio
# Only listen on wifi interface
interface=wlan0
# Always return 192.168.211.1 for any query not answered from /etc/hosts or DHCP and not sent to an upstream nameserver
address=/#/192.168.211.1
# DHCP server not active on wired lan interface
no-dhcp-interface=eth0
# IPv4 address range, netmask and lease time
dhcp-range=192.168.211.100,192.168.211.200,255.255.255.0,24h
# DNS server
dhcp-option=option:dns-server,192.168.211.1
expand-hosts
domain=local
# Facility to which dnsmasq will send syslog entries
log-facility=local7
EOF

log "Configuring hostapd"
cat <<-EOF >>/etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
channel=4
hw_mode=g
# Auth
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
# Volumio specific
ssid=Volumio
wpa_passphrase=volumio2
EOF

cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.tmpl
chmod -R 777 /etc/hostapd

log "Empty resolv.conf.head for custom DNS settings"
touch /etc/resolv.conf.head

log "Setting fallback DNS with OpenDNS nameservers"
cat <<-EOF >/etc/resolv.conf.tail.tmpl
# OpenDNS nameservers
nameserver 208.67.222.222
nameserver 208.67.220.220
EOF
chmod 666 /etc/resolv.conf.*

ln -s /etc/resolv.conf.tail.tmpl /etc/resolv.conf.tail

log "Removing Avahi Service for UDISK-SSH"
rm -f /etc/avahi/services/udisks.service

#####################
#CPU  Optimizations#-----------------------------------------
#####################

log "Setting CPU governor to performance" "info"
echo 'GOVERNOR="performance"' >/etc/default/cpufrequtils

log "Finished Volumio chroot configuration for ${DISTRO_NAME}" "okay"
