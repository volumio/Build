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
echo 'alias reboot="sudo /sbin/reboot"
alias poweroff="sudo /sbin/poweroff"
alias halt="sudo /sbin/halt"
alias shutdown="sudo /sbin/shutdown"
alias apt-get="sudo /usr/bin/apt-get"
alias systemctl="/bin/systemctl"' >> /etc/bash.bashrc

#Sudoers Nopasswd
echo 'Adding Safe Sudoers NoPassw permissions'
echo "volumio ALL=(ALL) NOPASSWD: /sbin/poweroff,/sbin/shutdown,/sbin/reboot,/sbin/halt,/bin/systemctl,/usr/bin/apt-get" >> /etc/sudoers


echo "Configuring Default Network"
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

EOF
chmod 600 /etc/network/interfaces

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
wget http://node-arm.herokuapp.com/node_latest_armhf.deb
dpkg -i /node_latest_armhf.deb 
rm /node_latest_armhf.deb 

echo "Installing Spop and libspotify"
wget http://repo.volumio.org/Packages/Spop/spop.tar.gz
tar xvf /spop.tar.gz
rm /spop.tar.gz

echo "Installing custom MPD version"
wget http://repo.volumio.org/Packages/Mpd/mpd_0.19.9-2_armhf.deb
dpkg -i mpd_0.19.9-2_armhf.deb
rm /mpd_0.19.9-2_armhf.deb

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


echo "Installing LINN Songcast module"
wget http://repo.volumio.org/Packages/Upmpdcli/sc2mpd_0.11.0-1_armhf.deb
dpkg -i sc2mpd_0.11.0-1_armhf.deb
rm /sc2mpd_0.11.0-1_armhf.deb

elif [ $(uname -m) = i686 ]; then
echo 'X86 Environment Detected' 

# cleanup
apt-get clean
rm -rf tmp/*

echo "Installing Node Environment"
wget https://deb.nodesource.com/node_0.12/pool/main/n/nodejs/nodejs_0.12.0-1nodesource1~jessie1_i386.deb
dpkg -i /nodejs_0.12.0-1nodesource1~jessie1_i386.deb
rm /nodejs_0.12.0-1nodesource1~jessie1_i386.deb

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
systemctl enable volumio.service

echo "Setting Mpd to SystemD instead of Init"
update-rc.d mpd remove
systemctl enable mpd.service

echo "Prepping Node Volumio folder"
mkdir /volumio
chown -R volumio:volumio /volumio

echo "Cloning Volumio"
git clone https://github.com/volumio/Volumio2.git /volumio

echo "Installing Volumio Modules"
cd /volumio
npm install --unsafe-perm

#####################
#Audio Optimizations#-----------------------------------------
#####################

echo "Creating Audio Group"
groupadd audio

echo "Adding Users to Audio Group"
usermod -a -G audio volumio
usermod -a -G audio mpd

echo "Setting RT Priority to Audio Group"
echo '@audio - rtprio 99
@audio - memlock unlimited' >> /etc/security/limits.conf

echo "Alsa tuning"
#Nrpacks Options, better safe than sorry
echo 'options snd-usb-audio nrpacks=1
options snd-usb-audio index=0' > /etc/modprobe.d/alsa-base.conf

echo "Tuning LAN"
echo 'fs.inotify.max_user_watches = 524288' >> /etc/sysctl.conf

