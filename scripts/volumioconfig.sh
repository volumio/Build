#!/bin/bash

# This script will be run in chroot under qemu.

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C
/var/lib/dpkg/info/dash.preinst install
dpkg --configure -a


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
' >> /etc/bash.bashrc

#Sudoers Nopasswd
echo 'Adding Safe Sudoers NoPassw permissions'
echo "volumio ALL=(ALL) NOPASSWD: /sbin/poweroff,/sbin/shutdown,/sbin/reboot,/sbin/halt,/bin/systemctl,/usr/bin/apt-get,/usr/sbin/update-rc.d,/usr/bin/gpio,/bin/mount,/bin/umount/,/sbin/iwconfig,/sbin/iwlist,/sbin/ifconfig,/usr/bin/killall,/bin/ip,/usr/sbin/service,/etc/init.d/netplug,/bin/journalctl,/bin/chmod" >> /etc/sudoers


echo "Configuring Default Network"
cat > /etc/network/interfaces << EOF

auto wlan0
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp

allow-hotplug wlan0
iface wlan0 inet dhcp
 wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOF
chmod 666 /etc/network/interfaces

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

# cleanup
  apt-get clean
  rm -rf tmp/*

  echo "Installing ARM Node Environment"
  # version 5.5. 0
  cd /
  wget http://repo.volumio.org/Volumio2/Binaries/arm/node-v5.5.0-linux-armv6l.tar.xz
  tar xf node-v5.5.0-linux-armv6l.tar.xz
  rm /node-v5.5.0-linux-armv6l.tar.xz
  cd /node-v5.5.0-linux-armv6l
  cp -rp bin/ include/ lib/ share/ /
  cd /
  rm -rf /node-v5.5.0-linux-armv6l

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

  echo "Installing Spop and libspotify"
  wget http://repo.volumio.org/Packages/Spop/spop.tar.gz
  tar xf /spop.tar.gz
  rm /spop.tar.gz

  echo "Installing custom MPD version"
  wget http://repo.volumio.org/Packages/Mpd/mpd_0.19.9-2_armhf.deb
  dpkg -i mpd_0.19.9-2_armhf.deb
  rm /mpd_0.19.9-2_armhf.deb

  echo "Installing Shairport for Airplay emulation"
  wget http://repo.volumio.org/Volumio2/Binaries/shairport-sync_arm.tar.gz
  tar xf shairport-sync_arm.tar.gz
  rm /shairport-sync_arm.tar.gz

  echo "Installing Upmpdcli"
  wget http://repo.volumio.org/Packages/Upmpdcli/arm/upmpdcli_1.1.0-1_armhf.deb
 wget http://repo.volumio.org/Packages/Upmpdcli/arm/libupnpp2_0.14.1-1_armhf.deb
 wget http://repo.volumio.org/Packages/Upmpdcli/arm/libupnp6_13a1.6.19.jfd2-1_armhf.deb
 dpkg -i libupnpp2_0.14.1-1_armhf.deb
 dpkg -i libupnp6_13a1.6.19.jfd2-1_armhf.deb
 dpkg -i upmpdcli_1.1.0-1_armhf.deb
 rm /upmpdcli_1.1.0-1_armhf.deb
 rm /libupnp6_13a1.6.19.jfd2-1_armhf.deb
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

elif [ $(uname -m) = i686 ] || [ $(uname -m) = x86 ] || [ $(uname -m) = x86_64 ]  ; then
  echo 'X86 Environment Detected'

# cleanup
  apt-get clean
  rm -rf tmp/*

  echo "Installing X86 Node Environment"
  cd /
  wget http://repo.volumio.org/Volumio2/Binaries/x86/node-v5.5.0-linux-x86.tar.xz
  tar xf node-v5.5.0-linux-x86.tar.xz
  rm /node-v5.5.0-linux-x86.tar.xz
  cd /node-v5.5.0-linux-x86
  cp -rp bin/ include/ lib/ share/ /
  cd /
  rm -rf /node-v5.5.0-linux-x86

  # Symlinking to legacy paths
  ln -s /bin/node /usr/local/bin/node
  ln -s /bin/npm /usr/local/bin/npm

  echo "Installing Volumio Modules"
  cd /volumio
  npm install --unsafe-perm


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

  echo "Installing Spop and libspotify"
  wget http://repo.volumio.org/Packages/Spop/spopx86.tar.gz
  tar xvf /spopx86.tar.gz
  rm /spopx86.tar.gz

  echo "Installing Upmpdcli"
  wget http://repo.volumio.org/Packages/Upmpdcli/upmpdcli_0.11.0-2_i386.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/libupnpp0_0.9.0-1_i386.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/libupnp6_1.6.19.jfd1-1_i386.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/libupnpp2_0.11.0-1_i386.deb
  dpkg -i libupnpp2_0.11.0-1_i386.deb
  dpkg -i libupnp6_1.6.19.jfd1-1_i386.deb
  dpkg -i upmpdcli_0.11.0-2_i386.deb
  dpkg -i libupnpp0_0.9.0-1_i386.deb
  rm /upmpdcli_0.11.0-2_i386.deb
  rm /libupnpp0_0.9.0-1_i386.deb
  rm /libupnp6_1.6.19.jfd1-1_i386.deb
  rm /libupnpp2_0.11.0-1_i386.deb


  echo "Installing LINN Songcast module"
  wget http://repo.volumio.org/Packages/Upmpdcli/sc2mpd_0.11.0-1_i386.deb
  dpkg -i sc2mpd_0.11.0-1_i386.deb
  rm /sc2mpd_0.11.0-1_i386.deb
  rm /libmicrohttpd10_0.9.37+dfsg-1+b1_i386.deb

  echo "Adding volumio-remote-updater"
  #TODO: wget http://repo.volumio.org/Volumio2/Binaries/x86/volumio-remote-updater -P /usr/local/sbin/
  #chmod a+x /usr/local/sbin/volumio-remote-updater


fi

echo "Creating Volumio Folder Structure"
# Media Mount Folders
mkdir /mnt/NAS
mkdir /media
chmod -R 777 /mnt
chmod -R 777 /media
# Symlinking Mount Folders to Mpd's Folder
ln -s /mnt/NAS /var/lib/mpd/music
ln -s /media /var/lib/mpd/music/USB

echo "Prepping MPD environment"
touch /var/lib/mpd/tag_cache
chmod 777 /var/lib/mpd/tag_cache
chmod 777 /var/lib/mpd/playlists

echo "Adding Volumio Parent Service to Startup"
#systemctl enable volumio.service
ln -s /lib/systemd/system/volumio.service /etc/systemd/system/multi-user.target.wants/volumio.service

echo "Adding Volumio Remote Updater Service to Startup"
#systemctl enable volumio-remote-updater.service
ln -s /lib/systemd/system/volumio-remote-updater.service /etc/systemd/system/multi-user.target.wants/volumio-remote-updater.service

echo "Adding Udisks-glue service to Startup"
ln -s /lib/systemd/system/udisks-glue.service /etc/systemd/system/multi-user.target.wants/udisks-glue.service

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

echo "Tuning LAN"
echo 'fs.inotify.max_user_watches = 524288' >> /etc/sysctl.conf

echo "Disabling IPV6"
echo "#disable ipv6" | tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" | tee -a /etc/sysctl.conf
