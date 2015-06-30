#!/bin/bash

# This script will be run in chroot under qemu.

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C
/var/lib/dpkg/info/dash.preinst install
dpkg --configure -a


#Adding Main user Volumio
echo "Adding Volumio User"
groupadd volumio
useradd -c volumio -d /home/volumio -m -g volumio -G adm,dialout,cdrom,floppy,audio,dip,video,plugdev -s /bin/bash -p '$6$tRtTtICB$Ki6z.DGyFRopSDJmLUcf3o2P2K8vr5QxRx5yk3lorDrWUhH64GKotIeYSNKefcniSVNcGHlFxZOqLM6xiDa.M.' volumio
echo "volumio ALL=(ALL) ALL" >> /etc/sudoers

#Setting Root Password
echo 'root:$1$JVNbxLRo$pNn5AmZxwRtWZ.xF.8xUq/' | chpasswd -e

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
wget http://repo.volumio.org/Packages/spop.tar.gz
tar xvf /spop.tar.gz
rm /spop.tar.gz

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
wget http://repo.volumio.org/Packages/spopx86.tar.gz
tar xvf /spopx86.tar.gz
rm /spopx86.tar.gz


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
