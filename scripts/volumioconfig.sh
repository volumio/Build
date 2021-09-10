#!/bin/bash

NODE_VERSION=8.11.1

# This script will be run in chroot under qemu.

echo "Prevent services starting during install, running under chroot"
echo "(avoids unnecessary errors)"
cat > /usr/sbin/policy-rc.d << EOF
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

echo "Configuring dpkg to not include Manual pages and docs"
echo "path-exclude /usr/share/doc/*
# we need to keep copyright files for legal reasons
path-include /usr/share/doc/*/copyright
path-exclude /usr/share/man/*
path-exclude /usr/share/groff/*
path-exclude /usr/share/info/*
# lintian stuff is small, but really unnecessary
path-exclude /usr/share/lintian/*
path-exclude /usr/share/linda/*" > /etc/dpkg/dpkg.cfg.d/01_nodoc


export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C
/var/lib/dpkg/info/dash.preinst install

#if [ $(uname -m) = i686 ] || [ $(uname -m) = x86 ] || [ $(uname -m) = x86_64 ]  ; then
#  echo "Fix for cgmanager not starting on x86"
#  sed -i -e 's/# Required-Start:    mountkernfs/# Required-Start:/g' /etc/init.d/cgmanager
#  dpkg --configure --force-all cgmanager
#  sed -i -e 's/# Required-Start:    mountkernfs/# Required-Start:/g' /etc/init.d/cgmanager
#fi

echo "Configuring packages"
dpkg --configure -a

# Reduce locales to just one beyond C.UTF-8
echo "Existing locales:"
locale -a
echo "Generating required locales:"
[ -f /etc/locale.gen ] || touch -m /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "Removing unused locales"
echo "en_US.UTF-8" >> /etc/locale.nopurge
# To remove existing locale data we must turn off the dpkg hook
sed -i -e 's/^USE_DPKG/#USE_DPKG/' /etc/locale.nopurge
# Ensure that the package knows it has been configured
sed -i -e 's/^NEEDSCONFIGFIRST/#NEEDSCONFIGFIRST/' /etc/locale.nopurge
dpkg-reconfigure localepurge -f noninteractive
localepurge
# Turn dpkg feature back on, it will handle further locale-cleaning
sed -i -e 's/^#USE_DPKG/USE_DPKG/' /etc/locale.nopurge
dpkg-reconfigure localepurge -f noninteractive
echo "Final locale list"
locale -a
echo ""

#Adding Main user Volumio
echo "Adding Volumio User"
groupadd volumio
useradd -c volumio -d /home/volumio -m -g volumio -G adm,dialout,cdrom,floppy,audio,dip,video,plugdev,netdev,lp,systemd-journal,input -s /bin/bash -p '$6$tRtTtICB$Ki6z.DGyFRopSDJmLUcf3o2P2K8vr5QxRx5yk3lorDrWUhH64GKotIeYSNKefcniSVNcGHlFxZOqLM6xiDa.M.' volumio

#Setting Root Password
echo 'root:$1$JVNbxLRo$pNn5AmZxwRtWZ.xF.8xUq/' | chpasswd -e

#Global BashRC Aliases"
echo 'Setting BashRC for custom system calls'
echo ' ## System Commands ##
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
' >> /etc/bash.bashrc

#Sudoers Nopasswd
SUDOERS_FILE="/etc/sudoers.d/volumio-user"
echo 'Adding Safe Sudoers NoPassw permissions'
cat > ${SUDOERS_FILE} << EOF
# Add permissions for volumio user
volumio ALL=(ALL) ALL
volumio ALL=(ALL) NOPASSWD: /sbin/poweroff,/sbin/shutdown,/sbin/reboot,/sbin/halt,/bin/systemctl,/usr/bin/apt-get,/usr/sbin/update-rc.d,/usr/bin/gpio,/bin/mount,/bin/umount,/sbin/iwconfig,/sbin/iwlist,/sbin/ifconfig,/usr/bin/killall,/bin/ip,/usr/sbin/service,/etc/init.d/netplug,/bin/journalctl,/bin/chmod,/sbin/ethtool,/usr/sbin/alsactl,/bin/tar,/usr/bin/dtoverlay,/sbin/dhclient,/usr/sbin/i2cdetect,/sbin/dhcpcd,/usr/bin/alsactl,/bin/mv,/sbin/iw,/bin/hostname,/sbin/modprobe,/sbin/iwgetid,/bin/ln,/usr/bin/unlink,/bin/dd,/usr/bin/dcfldd,/opt/vc/bin/vcgencmd,/opt/vc/bin/tvservice,/usr/bin/renice,/bin/rm,/bin/kill,/usr/sbin/i2cset
volumio ALL=(ALL) NOPASSWD: /bin/sh /volumio/app/plugins/system_controller/volumio_command_line_client/commands/kernelsource.sh, /bin/sh /volumio/app/plugins/system_controller/volumio_command_line_client/commands/pull.sh
EOF
chmod 0440 ${SUDOERS_FILE}

echo volumio > /etc/hostname
chmod 777 /etc/hostname
chmod 777 /etc/hosts

echo "nameserver 8.8.8.8" > /etc/resolv.conf

################
#Volumio System#---------------------------------------------------
################
if [ $(uname -m) = armv7l ] || [ $(uname -m) = aarch64 ]; then
  echo "Arm Environment detected"
  echo ' Adding Raspbian Repo Key'
  wget https://archive.raspbian.org/raspbian.public.key -O - | sudo apt-key add -

  echo "Installing ARM Node Environment"
  wget http://repo.volumio.org/Volumio2/node-v${NODE_VERSION}-linux-armv6l.tar.xz
  tar xf node-v${NODE_VERSION}-linux-armv6l.tar.xz
  rm /node-v${NODE_VERSION}-linux-armv6l.tar.xz
  cd /node-v${NODE_VERSION}-linux-armv6l
  cp -rp bin/ include/ lib/ share/ /
  cd /
  rm -rf /node-v${NODE_VERSION}-linux-armv6l


  # Symlinking to legacy paths
  ln -s /bin/node /usr/local/bin/node
  ln -s /bin/npm /usr/local/bin/npm

  echo "Installing Volumio Modules"
  cd /volumio
  wget http://repo.volumio.org/Volumio2/node_modules_arm-${NODE_VERSION}.tar.gz
  tar xf node_modules_arm-${NODE_VERSION}.tar.gz
  rm node_modules_arm-${NODE_VERSION}.tar.gz

  echo "Setting proper ownership"
  chown -R volumio:volumio /volumio

  echo "Creating Data Path"
  mkdir /data
  chown -R volumio:volumio /data

  echo "Creating ImgPart Path"
  mkdir /imgpart
  chown -R volumio:volumio /imgpart

  echo "Changing os-release permissions"
  chown volumio:volumio /etc/os-release
  chmod 777 /etc/os-release

  echo "Installing Custom Packages"
  cd /

  ARCH=$(cat /etc/os-release | grep ^VOLUMIO_ARCH | tr -d 'VOLUMIO_ARCH="')
  echo $ARCH
  echo "Installing custom MPD depending on system architecture"

  if [ $ARCH = arm ]; then

     echo "Installing MPD for armv6"
     # First we manually install a newer alsa-lib to achieve Direct DSD support

     echo "Installing alsa-lib 1.1.3"
     wget http://repo.volumio.org/Volumio2/Binaries/libasound2/armv6/libasound2_1.1.3-5_armhf.deb
     wget http://repo.volumio.org/Volumio2/Binaries/libasound2/armv6/libasound2-data_1.1.3-5_all.deb
     wget http://repo.volumio.org/Volumio2/Binaries/libasound2/armv6/libasound2-dev_1.1.3-5_armhf.deb
     dpkg --force-all -i libasound2-data_1.1.3-5_all.deb
     dpkg --force-all -i libasound2_1.1.3-5_armhf.deb
     dpkg --force-all -i libasound2-dev_1.1.3-5_armhf.deb
     rm libasound2-data_1.1.3-5_all.deb
     rm libasound2_1.1.3-5_armhf.deb
     rm libasound2-dev_1.1.3-5_armhf.deb

     echo "Installing MPD 20.18"
     wget http://repo.volumio.org/Volumio2/Binaries/mpd-DSD/mpd_0.20.18-1_armv6.deb
     dpkg -i mpd_0.20.18-1_armv6.deb
     rm mpd_0.20.18-1_armv6.deb

     echo "Installing Upmpdcli for armv6"
     wget http://repo.volumio.org/Volumio2/Binaries/upmpdcli/armv6/libupnpp3_0.15.1-1_armhf.deb
     wget http://repo.volumio.org/Volumio2/Binaries/upmpdcli/armv6/libupnp6_1.6.20.jfd5-1_armhf.deb
     wget http://repo.volumio.org/Volumio2/Binaries/upmpdcli/armv6/upmpdcli_1.2.12-1_armhf.deb
     dpkg -i libupnpp3_0.15.1-1_armhf.deb
     dpkg -i libupnp6_1.6.20.jfd5-1_armhf.deb
     dpkg -i upmpdcli_1.2.12-1_armhf.deb
     rm libupnpp3_0.15.1-1_armhf.deb
     rm libupnp6_1.6.20.jfd5-1_armhf.deb
     rm upmpdcli_1.2.12-1_armhf.deb

     echo "Adding volumio-remote-updater for armv6"
     wget http://repo.volumio.org/Volumio2/Binaries/arm/volumio-remote-updater_1.3-armhf.deb
     dpkg -i volumio-remote-updater_1.3-armhf.deb
     rm volumio-remote-updater_1.3-armhf.deb


  elif [ $ARCH = armv7 ]; then
     echo "Installing MPD for armv7"
     # First we manually install a newer alsa-lib to achieve Direct DSD support

     echo "Installing alsa-lib 1.1.3"
     wget http://repo.volumio.org/Volumio2/Binaries/libasound2/armv7/libasound2_1.1.3-5_armhf.deb
     wget http://repo.volumio.org/Volumio2/Binaries/libasound2/armv7/libasound2-data_1.1.3-5_all.deb
     wget http://repo.volumio.org/Volumio2/Binaries/libasound2/armv7/libasound2-dev_1.1.3-5_armhf.deb
     dpkg --force-all -i libasound2-data_1.1.3-5_all.deb
     dpkg --force-all -i libasound2_1.1.3-5_armhf.deb
     dpkg --force-all -i libasound2-dev_1.1.3-5_armhf.deb
     rm libasound2-data_1.1.3-5_all.deb
     rm libasound2_1.1.3-5_armhf.deb
     rm libasound2-dev_1.1.3-5_armhf.deb

     echo "Installing MPD 20.18"
     wget http://repo.volumio.org/Volumio2/Binaries/mpd-DSD/mpd_0.20.18-1_armv7.deb
     dpkg -i mpd_0.20.18-1_armv7.deb
     rm mpd_0.20.18-1_armv7.deb

    echo "Installing Upmpdcli for armv7"
    wget http://repo.volumio.org/Volumio2/Binaries/upmpdcli/armv7/libupnpp3_0.15.1-1_armhf.deb
    wget http://repo.volumio.org/Volumio2/Binaries/upmpdcli/armv7/libupnp6_1.6.20.jfd5-1_armhf.deb
    wget http://repo.volumio.org/Volumio2/Binaries/upmpdcli/armv7/upmpdcli_1.2.12-1_armhf.deb
    dpkg -i libupnpp3_0.15.1-1_armhf.deb
    dpkg -i libupnp6_1.6.20.jfd5-1_armhf.deb
    dpkg -i upmpdcli_1.2.12-1_armhf.deb
    rm libupnpp3_0.15.1-1_armhf.deb
    rm libupnp6_1.6.20.jfd5-1_armhf.deb
    rm upmpdcli_1.2.12-1_armhf.deb

    echo "Adding volumio-remote-updater for armv7"
    wget http://repo.volumio.org/Volumio2/Binaries/arm/volumio-remote-updater_1.3-armv7.deb
    dpkg -i volumio-remote-updater_1.3-armv7.deb
    rm volumio-remote-updater_1.3-armv7.deb

  fi
  #Remove autostart of upmpdcli
  update-rc.d upmpdcli remove

  echo "Installing Shairport-Sync"
  wget http://repo.volumio.org/Volumio2/Binaries/shairport-sync_3.3.6-arm.deb
  dpkg -i shairport-sync_3.3.6-arm.deb
  rm shairport-sync_3.3.6-arm.deb

  echo "Installing Shairport-Sync Metadata Reader"
  wget http://repo.volumio.org/Volumio2/Binaries/shairport-sync-metadata-reader-arm.tar.gz
  tar xf shairport-sync-metadata-reader-arm.tar.gz
  rm /shairport-sync-metadata-reader-arm.tar.gz

  echo "Volumio Init Updater"
  wget http://repo.volumio.org/Volumio2/Binaries/arm/volumio-init-updater-v2 -O /usr/local/sbin/volumio-init-updater
  chmod a+x /usr/local/sbin/volumio-init-updater

  echo "Installing Snapcast for multiroom"
  wget http://repo.volumio.org/Volumio2/Binaries/arm/snapserver -P /usr/sbin/
  wget http://repo.volumio.org/Volumio2/Binaries/arm/snapclient -P  /usr/sbin/
  chmod a+x /usr/sbin/snapserver
  chmod a+x /usr/sbin/snapclient

  echo "Installing Zsync"
  rm /usr/bin/zsync
  wget http://repo.volumio.org/Volumio2/Binaries/arm/zsync -P /usr/bin/
  chmod a+x /usr/bin/zsync

  echo "Adding special version for edimax dongle"
  wget http://repo.volumio.org/Volumio2/Binaries/arm/hostapd-edimax -P /usr/sbin/
  chmod a+x /usr/sbin/hostapd-edimax

  echo "Adding special version for kernel 4.19"
  wget http://repo.volumio.org/Volumio2/Binaries/arm/hostapd-2.8 -P /usr/sbin/
  chmod a+x /usr/sbin/hostapd-2.8

  echo "interface=wlan0
ssid=Volumio
channel=4
driver=rtl871xdrv
hw_mode=g
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=volumio2" >> /etc/hostapd/hostapd-edimax.conf
  chmod -R 777 /etc/hostapd/hostapd-edimax.conf

  echo "Cleanup"
  apt-get clean
  rm -rf tmp/*
elif [ $(uname -m) = i686 ] || [ $(uname -m) = x86 ] || [ $(uname -m) = x86_64 ]  ; then
  echo 'x86 Environment Detected'

  # cleanup
  apt-get clean
  rm -rf tmp/*

  echo "Installing x86 Node Environment"
  cd /
  wget http://repo.volumio.org/Volumio2/node-v${NODE_VERSION}-linux-x86.tar.xz
  tar xf node-v${NODE_VERSION}-linux-x86.tar.xz
  rm /node-v${NODE_VERSION}-linux-x86.tar.xz
  cd /node-v${NODE_VERSION}-linux-x86
  cp -rp bin/ include/ lib/ share/ /
  cd /
  rm -rf /node-v${NODE_VERSION}-linux-x86

  # Symlinking to legacy paths
  ln -s /bin/node /usr/local/bin/node
  ln -s /bin/npm /usr/local/bin/npm

  echo "Installing Volumio Modules"
  cd /volumio
  wget http://repo.volumio.org/Volumio2/node_modules_x86-${NODE_VERSION}.tar.gz
  tar xf node_modules_x86-${NODE_VERSION}.tar.gz
  rm node_modules_x86-${NODE_VERSION}.tar.gz


  echo "Setting proper ownership"
  chown -R volumio:volumio /volumio

  echo "Creating Data Path"
  mkdir /data
  chown -R volumio:volumio /data

  echo "Changing os-release permissions"
  chown volumio:volumio /etc/os-release
  chmod 777 /etc/os-release

  echo "Installing Custom Packages"
  cd /

  echo "Installing MPD for i386"
  # First we manually install a newer alsa-lib to achieve Direct DSD support

  echo "Installing alsa-lib 1.1.3"
  wget http://repo.volumio.org/Volumio2/Binaries/libasound2/i386/libasound2_1.1.3-5_i386.deb
  wget http://repo.volumio.org/Volumio2/Binaries/libasound2/i386/libasound2-data_1.1.3-5_all.deb
  wget http://repo.volumio.org/Volumio2/Binaries/libasound2/i386/libasound2-dev_1.1.3-5_i386.deb
  dpkg --force-all -i libasound2-data_1.1.3-5_all.deb
  dpkg --force-all -i libasound2_1.1.3-5_i386.deb
  dpkg --force-all -i libasound2-dev_1.1.3-5_i386.deb
  rm libasound2-data_1.1.3-5_all.deb
  rm libasound2_1.1.3-5_i386.deb
  rm libasound2-dev_1.1.3-5_i386.deb

  echo "Installing MPD 20.18"
  wget http://repo.volumio.org/Volumio2/Binaries/mpd-DSD/mpd_0.20.18-1_i386.deb
  dpkg -i mpd_0.20.18-1_i386.deb
  rm mpd_0.20.18-1_i386.deb

  echo "Installing Upmpdcli"
  wget http://repo.volumio.org/Packages/Upmpdcli/x86/upmpdcli_1.2.12-1_i386.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/x86/libupnp6_1.6.20.jfd5-1_i386.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/x86/libupnpp3_0.15.1-1_i386.deb
  dpkg -i libupnpp3_0.15.1-1_i386.deb
  dpkg -i libupnp6_1.6.20.jfd5-1_i386.deb
  dpkg -i upmpdcli_1.2.12-1_i386.deb
  rm /libupnpp3_0.15.1-1_i386.deb
  rm /upmpdcli_1.2.12-1_i386.deb
  rm /libupnp6_1.6.20.jfd5-1_i386.deb

  echo "Installing Shairport-Sync"
  wget http://repo.volumio.org/Volumio2/Binaries/shairport-sync_3.3.6-i386.deb
  dpkg -i shairport-sync_3.3.6-i386.deb
  rm shairport-sync_3.3.6-i386.deb

  echo "Installing Shairport-Sync Metadata Reader"
  wget http://repo.volumio.org/Volumio2/Binaries/shairport-sync-metadata-reader-i386.tar.gz
  tar xf shairport-sync-metadata-reader-i386.tar.gz
  rm /shairport-sync-metadata-reader-i386.tar.gz


  echo "Installing LINN Songcast module"
  wget http://repo.volumio.org/Packages/Upmpdcli/x86/sc2mpd_1.1.1-1_i386.deb
  dpkg -i sc2mpd_1.1.1-1_i386.deb
  rm /sc2mpd_1.1.1-1_i386.deb

  echo "Volumio Init Updater"
  wget http://repo.volumio.org/Volumio2/Binaries/x86/volumio-init-updater-v2 -O /usr/local/sbin/volumio-init-updater
  chmod a+x /usr/local/sbin/volumio-init-updater

  echo "Installing Zsync"
  rm /usr/bin/zsync
  wget http://repo.volumio.org/Volumio2/Binaries/x86/zsync -P /usr/bin/
  chmod a+x /usr/bin/zsync

  echo "Adding volumio-remote-updater for i386"
  wget http://repo.volumio.org/Volumio2/Binaries/x86/volumio-remote-updater_1.3-i386.deb
  dpkg -i volumio-remote-updater_1.3-i386.deb
  rm /volumio-remote-updater_1.3-i386.deb


fi

echo "Setting proper permissions for ping"
chmod u+s /bin/ping

echo "Creating Volumio Folder Structure"
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

# Symlinking Mount Folders to Mpd's Folder
ln -s /mnt/NAS /var/lib/mpd/music
ln -s /mnt/USB /var/lib/mpd/music
ln -s /mnt/INTERNAL /var/lib/mpd/music

echo "Prepping MPD environment"
touch /var/lib/mpd/tag_cache
chmod 777 /var/lib/mpd/tag_cache
chmod 777 /var/lib/mpd/playlists

echo "Setting mpdignore file"
echo "@Recycle
#recycle
$*
System Volume Information
$RECYCLE.BIN
RECYCLER
" > /var/lib/mpd/music/.mpdignore

echo "Setting mpc to bind to unix socket"
export MPD_HOST=/run/mpd/socket

echo "Setting Permissions for /etc/modules"
chmod 777 /etc/modules

echo "Adding Volumio Parent Service to Startup"
#systemctl enable volumio.service
ln -s /lib/systemd/system/volumio.service /etc/systemd/system/multi-user.target.wants/volumio.service

echo "Adding Udisks-glue service to Startup"
ln -s /lib/systemd/system/udisks-glue.service /etc/systemd/system/multi-user.target.wants/udisks-glue.service

echo "Adding First start script"
ln -s /lib/systemd/system/firststart.service /etc/systemd/system/multi-user.target.wants/firststart.service

echo "Adding Dynamic Swap Service"
ln -s /lib/systemd/system/dynamicswap.service /etc/systemd/system/multi-user.target.wants/dynamicswap.service

echo "Adding Iptables Service"
ln -s /lib/systemd/system/iptables.service /etc/systemd/system/multi-user.target.wants/iptables.service

echo "Disabling SSH by default"
systemctl disable ssh.service

echo "Enable Volumio SSH enabler"
ln -s /lib/systemd/system/volumiossh.service /etc/systemd/system/multi-user.target.wants/volumiossh.service

echo "Enable Volumio Log Rotation Service"
ln -s /lib/systemd/system/volumiologrotate.service /etc/systemd/system/multi-user.target.wants/volumiologrotate.service

echo "Setting Mpd to SystemD instead of Init"
update-rc.d mpd remove
systemctl enable mpd.service

echo "Preventing hotspot services from starting at boot"
systemctl disable hotspot.service
systemctl disable dnsmasq.service

echo "Preventing un-needed dhcp servers to start automatically"
systemctl disable isc-dhcp-server.service
systemctl disable dhcpd.service

echo "Linking Volumio Command Line Client"
ln -s /volumio/app/plugins/system_controller/volumio_command_line_client/volumio.sh /usr/local/bin/volumio
chmod a+x /usr/local/bin/volumio

echo "Adding Shairport-Sync User"
getent group shairport-sync &>/dev/null || groupadd -r shairport-sync >/dev/null
getent passwd shairport-sync &> /dev/null || useradd -r -M -g shairport-sync -s /usr/bin/nologin -G audio shairport-sync >/dev/null

echo "Semistandard"
ln -s /volumio/node_modules/semistandard/bin/cmd.js /bin/semistandard

#####################
#Audio Optimizations#-----------------------------------------
#####################

echo "Adding Users to Audio Group"
usermod -a -G audio volumio
usermod -a -G audio mpd

echo "Setting RT Priority to Audio Group"
echo '@audio - rtprio 99
@audio - memlock unlimited' >> /etc/security/limits.conf

echo "Alsa tuning"


echo "Creating Alsa state file"
touch /var/lib/alsa/asound.state
echo '#' > /var/lib/alsa/asound.state
chmod 777 /var/lib/alsa/asound.state

echo "Fixing UPNP L16 Playback issue"
grep -v '^@ENABLEL16' /usr/share/upmpdcli/protocolinfo.txt > /usr/share/upmpdcli/protocolinfo.txtrepl && mv /usr/share/upmpdcli/protocolinfo.txtrepl /usr/share/upmpdcli/protocolinfo.txt

#####################
#Network Settings and Optimizations#-----------------------------------------
#####################


echo "Tuning LAN"
echo 'fs.inotify.max_user_watches = 524288' >> /etc/sysctl.conf

echo "Disabling IPV6"
echo "#disable ipv6" | tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" | tee -a /etc/sysctl.conf

echo "Wireless"
ln -s /lib/systemd/system/wireless.service /etc/systemd/system/multi-user.target.wants/wireless.service

echo "Configuring hostapd"
echo "interface=wlan0
ssid=Volumio
channel=4
driver=nl80211
hw_mode=g
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=volumio2
" >> /etc/hostapd/hostapd.conf

echo "Hostapd conf files"
cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.tmpl
chmod -R 777 /etc/hostapd

echo "Empty resolv.conf.head for custom DNS settings"
touch /etc/resolv.conf.head

echo "Setting fallback DNS with OpenDNS nameservers"
echo "# OpenDNS nameservers
nameserver 208.67.222.222
nameserver 208.67.220.220" > /etc/resolv.conf.tail.tmpl
chmod 666 /etc/resolv.conf.*
ln -s /etc/resolv.conf.tail.tmpl /etc/resolv.conf.tail

echo "Removing Avahi Service for UDISK-SSH"
rm /etc/avahi/services/udisks.service

#####################
#CPU  Optimizations#-----------------------------------------
#####################

echo "Setting CPU governor to performance"
echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils

