#!/bin/bash

# This script will be run in chroot under qemu.

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C
/var/lib/dpkg/info/dash.preinst install
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
useradd -c volumio -d /home/volumio -m -g volumio -G adm,dialout,cdrom,floppy,audio,dip,video,plugdev,netdev -s /bin/bash -p '$6$tRtTtICB$Ki6z.DGyFRopSDJmLUcf3o2P2K8vr5QxRx5yk3lorDrWUhH64GKotIeYSNKefcniSVNcGHlFxZOqLM6xiDa.M.' volumio
echo "volumio ALL=(ALL) ALL" >> /etc/sudoers

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
alias volumio="/volumio/app/plugins/system_controller/volumio_command_line_client/volumio.sh"
' >> /etc/bash.bashrc

#Sudoers Nopasswd
echo 'Adding Safe Sudoers NoPassw permissions'
echo "volumio ALL=(ALL) NOPASSWD: /sbin/poweroff,/sbin/shutdown,/sbin/reboot,/sbin/halt,/bin/systemctl,/usr/bin/apt-get,/usr/sbin/update-rc.d,/usr/bin/gpio,/bin/mount,/bin/umount/,/sbin/iwconfig,/sbin/iwlist,/sbin/ifconfig,/usr/bin/killall,/bin/ip,/usr/sbin/service,/etc/init.d/netplug,/bin/journalctl,/bin/chmod,/sbin/ethtool,/usr/sbin/alsactl,/bin/tar,/usr/bin/dtoverlay,/sbin/dhclient,/usr/sbin/i2cdetect,/sbin/dhcpcd,/usr/bin/alsactl,/bin/mv,/sbin/iw,/bin/hostname" >> /etc/sudoers

#echo "Configuring Default Network"
#cat > /etc/network/interfaces << EOF

#auto wlan0
#auto lo
#iface lo inet loopback

#allow-hotplug eth0
#iface eth0 inet dhcp

#allow-hotplug wlan0
#iface wlan0 inet dhcp
# wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
#EOF
#chmod 666 /etc/network/interfaces

echo volumio > /etc/hostname
chmod 777 /etc/hostname
chmod 777 /etc/hosts

echo "nameserver 8.8.8.8" > /etc/resolv.conf

ln -s '/usr/lib/systemd/system/console-kit-daemon.service' '/etc/systemd/system/getty.target.wants/console-kit-daemon.service'


################
#Volumio System#---------------------------------------------------
################
if [ $(uname -m) = armv7l ]; then
  echo "Arm Environment detected"
  echo ' Adding Raspbian Repo Key'
  wget http://archive.raspbian.org/raspbian.public.key -O - | sudo apt-key add -

  echo "Installing ARM Node Environment"
  # version 6.3.0
  cd /
  wget https://nodejs.org/dist/v6.3.0/node-v6.3.0-linux-armv6l.tar.xz
  tar xf node-v6.3.0-linux-armv6l.tar.xz
  rm /node-v6.3.0-linux-armv6l.tar.xz
  cd /node-v6.3.0-linux-armv6l
  cp -rp bin/ include/ lib/ share/ /
  cd /
  rm -rf /node-v6.3.0-linux-armv6l

  # Symlinking to legacy paths
  ln -s /bin/node /usr/local/bin/node
  ln -s /bin/npm /usr/local/bin/npm

  echo "Installing Volumio Modules"
  cd /volumio
  wget http://repo.volumio.org/Volumio2/node_modules_arm.tar.gz
  tar xf node_modules_arm.tar.gz
  rm node_modules_arm.tar.gz

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

  #echo "Installing Spop and libspotify"
  #wget http://repo.volumio.org/Packages/Spop/spop.tar.gz
  #tar xf /spop.tar.gz
  #rm /spop.tar.gz

  echo "Installing custom MPD version"
  wget http://repo.volumio.org/Volumio2/Binaries/arm/mpd_0.19.19-1_armhf.deb
  dpkg -i mpd_0.19.19-1_armhf.deb
  rm /mpd_0.19.19-1_armhf.deb

  echo "Installing Shairport for Airplay emulation"
  wget http://repo.volumio.org/Volumio2/Binaries/shairport-sync_arm.tar.gz
  tar xf shairport-sync_arm.tar.gz
  rm /shairport-sync_arm.tar.gz

  echo "Installing Upmpdcli"
  wget http://repo.volumio.org/Packages/Upmpdcli/arm/upmpdcli_1.1.3-1_armhf.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/arm/libupnpp2_0.14.1-1_armhf.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/arm/libupnp6_1.6.19.jfd3-1_armhf.deb
  dpkg -i libupnpp2_0.14.1-1_armhf.deb
  dpkg -i libupnp6_1.6.19.jfd3-1_armhf.deb
  dpkg -i upmpdcli_1.1.3-1_armhf.deb
  rm /upmpdcli_1.1.3-1_armhf.deb
  rm /libupnp6_1.6.19.jfd3-1_armhf.deb
  rm /libupnpp2_0.14.1-1_armhf.deb

  #Remove autostart of upmpdcli
  update-rc.d upmpdcli remove

  #echo "Installing LINN Songcast module"
  #wget http://repo.volumio.org/Packages/Upmpdcli/sc2mpd_0.11.0-1_armhf.deb
  #dpkg -i sc2mpd_0.11.0-1_armhf.deb
  #rm /sc2mpd_0.11.0-1_armhf.deb

  echo "Installing Snapcast for multiroom"

  wget http://repo.volumio.org/Volumio2/Binaries/arm/snapserver -P /usr/sbin/
  wget http://repo.volumio.org/Volumio2/Binaries/arm/snapclient -P  /usr/sbin/
  chmod a+x /usr/sbin/snapserver
  chmod a+x /usr/sbin/snapclient

  echo "Zsync"
  rm /usr/bin/zsync
  wget http://repo.volumio.org/Volumio2/Binaries/arm/zsync -P /usr/bin/
  chmod a+x /usr/bin/zsync

  echo "Adding volumio-remote-updater"
  wget http://repo.volumio.org/Volumio2/Binaries/arm/volumio-remote-updater -P /usr/local/sbin/
  chmod a+x /usr/local/sbin/volumio-remote-updater

  echo "Installing winbind, its done here because else it will freeze networking"
  wget http://repo.volumio.org/Volumio2/Binaries/arm/libnss-winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb
  wget http://repo.volumio.org/Volumio2/Binaries/arm/winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb

  echo "Adding special version for edimax dongle"
  wget http://repo.volumio.org/Volumio2/Binaries/arm/hostapd-edimax -P /usr/sbin/
  chmod a+x /usr/sbin/hostapd-edimax

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
  chmod -R 777 /etc/hostapd-edimax.conf

  echo "Cleanup"
  apt-get clean
  rm -rf tmp/*
elif [ $(uname -m) = i686 ] || [ $(uname -m) = x86 ] || [ $(uname -m) = x86_64 ]  ; then
  echo 'X86 Environment Detected'

  # cleanup
  apt-get clean
  rm -rf tmp/*

  echo "Installing X86 Node Environment"
  cd /
  wget https://nodejs.org/dist/v6.3.0/node-v6.3.0-linux-x86.tar.xz
  tar xf node-v6.3.0-linux-x86.tar.xz
  rm /node-v6.3.0-linux-x86.tar.xz
  cd /node-v6.3.0-linux-x86
  cp -rp bin/ include/ lib/ share/ /
  cd /
  rm -rf /node-v6.3.0-linux-x86

  # Symlinking to legacy paths
  ln -s /bin/node /usr/local/bin/node
  ln -s /bin/npm /usr/local/bin/npm

  echo "Installing Volumio Modules"
  cd /volumio
  wget http://repo.volumio.org/Volumio2/node_modules_x86.tar.gz
  tar xf node_modules_x86.tar.gz
  rm node_modules_x86.tar.gz


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

  echo "Installing custom MPD version"
  wget http://repo.volumio.org/Volumio2/Binaries/x86/mpd_0.19.19-1_i386.deb
  dpkg -i mpd_0.19.19-1_i386.deb
  rm /mpd_0.19.19-1_i386.deb

  echo "Installing Upmpdcli"
  wget http://repo.volumio.org/Packages/Upmpdcli/x86/upmpdcli_1.1.3-1_i386.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/x86/libupnpp2_0.14.1-1_i386.deb
  dpkg -i libupnpp2_0.14.1-1_i386.deb
  dpkg -i upmpdcli_1.1.3-1_i386.deb
  rm /upmpdcli_1.1.3-1_i386.deb
  rm /libupnpp2_0.14.1-1_i386.deb

  echo "Installing Shairport-Sync"
  wget http://repo.volumio.org/Volumio2/Binaries/x86/shairport-sync_2.8.4-1_i386.deb
  wget http://repo.volumio.org/Volumio2/Binaries/x86/libssl1.0.2_1.0.2h-1_i386.deb
  dpkg -i libssl1.0.2_1.0.2h-1_i386.deb
  echo N | dpkg -i shairport-sync_2.8.4-1_i386.deb
  rm /libssl1.0.2_1.0.2h-1_i386.deb
  rm /shairport-sync_2.8.4-1_i386.deb


  echo "Installing LINN Songcast module"
  wget http://repo.volumio.org/Packages/Upmpdcli/x86/sc2mpd_1.1.1-1_i386.deb
  dpkg -i sc2mpd_1.1.1-1_i386.deb
  rm /sc2mpd_1.1.1-1_i386.deb

  echo "Volumio Init Updater"
  wget -P /usr/local/sbin/volumio-init-updater http://repo.volumio.org/Volumio2/Binaries/x86/volumio-init-updater
  chmod a+x /usr/local/sbin/volumio-init-updater

  echo "Zsync"
  rm /usr/bin/zsync
  wget http://repo.volumio.org/Volumio2/Binaries/x86/zsync -P /usr/bin/
  chmod a+x /usr/bin/zsync

  echo "Adding volumio-remote-updater"
  wget http://repo.volumio.org/Volumio2/Binaries/x86/volumio-remote-updater -P /usr/local/sbin/
  chmod a+x /usr/local/sbin/volumio-remote-updater


fi

echo "Creating Volumio Folder Structure"
# Media Mount Folders
mkdir /mnt/NAS
mkdir /media
ln -s /media /mnt/USB

#Internal Storage Folder
mkdir /data/INTERNAL
ln -s /data/INTERNAL /mnt/INTERNAL

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

echo "Setting Permissions for /etc/modules"
chmod 777 /etc/modules

echo "Adding Volumio Parent Service to Startup"
#systemctl enable volumio.service
ln -s /lib/systemd/system/volumio.service /etc/systemd/system/multi-user.target.wants/volumio.service

echo "Adding Volumio Remote Updater Service to Startup"
#systemctl enable volumio-remote-updater.service
ln -s /lib/systemd/system/volumio-remote-updater.service /etc/systemd/system/multi-user.target.wants/volumio-remote-updater.service

echo "Adding Udisks-glue service to Startup"
ln -s /lib/systemd/system/udisks-glue.service /etc/systemd/system/multi-user.target.wants/udisks-glue.service

echo "Adding First start script"
ln -s /lib/systemd/system/firststart.service /etc/systemd/system/multi-user.target.wants/firststart.service

echo "Adding Dynamic Swap Service"
ln -s /lib/systemd/system/dynamicswap.service /etc/systemd/system/multi-user.target.wants/dynamicswap.service

echo "Setting Mpd to SystemD instead of Init"
update-rc.d mpd remove
systemctl enable mpd.service

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

echo "Setting default DNS with Google's DNS"
echo "# Google nameservers
nameserver 8.8.8.8
nameserver 8.8.4.4" >> /etc/resolv.conf.head

echo "Removing Avahi Service for UDISK-SSH"
rm /etc/avahi/services/udisks.service
