#!/bin/bash

# This script will be run in chroot under qemu.

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C
/var/lib/dpkg/info/dash.preinst install
dpkg --configure -a


#Adding Main user Volumio
groupadd volumio
useradd -c volumio -d /home/volumio -m -g volumio -G adm,dialout,cdrom,floppy,audio,dip,video,plugdev -s /bin/bash -p '$6$NmS08H8I$ujkaSrFD0PH1X/8dNotF0KFnQhpJ8hHrGmlpl9Key6FBnVQ4diL4Bmgmc3tCyAyt.PPzK5ChURbZn.XL3rCv51' volumio
echo "volumio ALL=(ALL) ALL" >> /etc/sudoers

#Setting Root Password
echo 'root:$1$JVNbxLRo$pNn5AmZxwRtWZ.xF.8xUq/' | chpasswd -e



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

# cleanup
apt-get clean

rm -rf tmp/*
rm configscript.sh 
