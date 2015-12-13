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
alias service="/usr/sbin/service"
' >> /etc/bash.bashrc

#Sudoers Nopasswd
echo 'Adding Safe Sudoers NoPassw permissions'
echo "volumio ALL=(ALL) NOPASSWD: /sbin/poweroff,/sbin/shutdown,/sbin/reboot,/sbin/halt,/bin/systemctl,/usr/bin/apt-get,/usr/sbin/update-rc.d,/usr/bin/gpio,/bin/mount,/bin/umount/,/sbin/iwconfig,/sbin/iwlist,/sbin/ifconfig,/usr/bin/killall,/bin/ip,/usr/sbin/service,/etc/init.d/netplug,/bin/journalctl
" >> /etc/sudoers


echo "Configuring Default Network"
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

EOF
chmod 666 /etc/network/interfaces

echo volumio > /etc/hostname

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

  echo "Installing Node Environment"
#huge kudos to node-arm for such effort	
  wget http://repo.volumio.org/Volumio2/node_0.12.6-1_armhf.deb
  dpkg -i /node_0.12.6-1_armhf.deb
  rm /node_0.12.6-1_armhf.deb

  echo "Installing Volumio Modules"
  cd /volumio
  wget http://repo.volumio.org/Volumio2/node_modules_arm.tar.gz
  tar xf node_modules_arm.tar.gz
  rm node_modules_arm.tar.gz

  echo "Installing Static UI"
#svn checkout https://github.com/volumio/Volumio2-UI/trunk/dist http/www
#cd /
# TO DO: FInd a better way to do this 
  cd /
  wget http://repo.volumio.org/Volumio2/volumio-ui.tar.gz
  tar xf volumio-ui.tar.gz 
  rm /volumio-ui.tar.gz

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
  wget http://repo.volumio.org/Packages/Upmpdcli/upmpdcli_0.11.2-1_armhf.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/libupnpp0_0.9.0-1_armhf.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/libupnp6_1.6.19.jfd1-2_armhf.deb
  wget http://repo.volumio.org/Packages/Upmpdcli/libupnpp2_0.11.0-1_armhf.deb
  dpkg -i libupnpp2_0.11.0-1_armhf.deb
  dpkg -i libupnpp0_0.9.0-1_armhf.deb
  dpkg -i libupnp6_1.6.19.jfd1-2_armhf.deb
  dpkg -i upmpdcli_0.11.2-1_armhf.deb
  rm /upmpdcli_0.11.2-1_armhf.deb
  rm /libupnpp0_0.9.0-1_armhf.deb
  rm /libupnp6_1.6.19.jfd1-2_armhf.deb
  rm /libupnpp2_0.11.0-1_armhf.deb

#Remove autostart of upmpdcli
  update-rc.d upmpdcli remove

  echo "Installing LINN Songcast module"
  wget http://repo.volumio.org/Packages/Upmpdcli/sc2mpd_0.11.0-1_armhf.deb
  dpkg -i sc2mpd_0.11.0-1_armhf.deb
  rm /sc2mpd_0.11.0-1_armhf.deb

  echo "Installing Snapcast for multiroom"

  wget http://repo.volumio.org/Volumio2/Binaries/snapserver -P /usr/sbin/
  wget http://repo.volumio.org/Volumio2/Binaries/snapclient -P  /usr/sbin/
  chmod a+x /usr/sbin/snapserver
  chmod a+x /usr/sbin/snapclient

elif [ $(uname -m) = i686 ] || [ $(uname -m) = x86 ] || [ $(uname -m) = x86_64 ]  ; then
  echo 'X86 Environment Detected' 

# cleanup
  apt-get clean
  rm -rf tmp/*

  echo "Installing Node Environment"
  wget https://deb.nodesource.com/node_0.12/pool/main/n/nodejs/nodejs_0.12.0-1nodesource1~jessie1_i386.deb
  dpkg -i /nodejs_0.12.0-1nodesource1~jessie1_i386.deb
  rm /nodejs_0.12.0-1nodesource1~jessie1_i386.deb

  #echo "Cloning Volumio" 
  #git clone https://github.com/volumio/Volumio2.git /volumio

  echo "Installing Volumio Modules"
  cd /volumio
  npm install --unsafe-perm

  echo "Getting Static UI"
#svn checkout https://github.com/volumio/Volumio2-UI/trunk/dist http/www
#cd /
# TO DO: FInd a better way to do this 
  cd /
  wget http://repo.volumio.org/Volumio2/volumio-ui.tar.gz
  tar xf volumio-ui.tar.gz 
  rm /volumio-ui.tar.gz

  echo "Setting proper ownership"
  chown -R volumio:volumio /volumio

  echo "Creating Data Path"
  mkdir /data
  chown -R volumio:volumio /data

  echo "Changing os-release permissions"
  chown volumio:volumio /etc/os-release
  chmod 777 /etc/os-release

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

fi

echo "Creating Volumio Folder Structure"
# Media Mount Folders
mkdir /mnt/NAS
mkdir /mnt/USB
chmod -R 777 /mnt
# Symlinking Mount Folders to Mpd's Folder
ln -s /mnt/NAS /var/lib/mpd/music
ln -s /mnt/USB /var/lib/mpd/music

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
#Nrpacks Options, better safe than sorry
#echo 'options snd-usb-audio nrpacks=1' >> /etc/modprobe.d/alsa-base.conf

echo "Creating Alsa state file"
touch /var/lib/alsa/asound.state
echo '#' > /var/lib/alsa/asound.state
chmod 777 /var/lib/alsa/asound.state

echo "Tuning LAN"
echo 'fs.inotify.max_user_watches = 524288' >> /etc/sysctl.conf

