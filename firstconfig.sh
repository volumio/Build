#!/bin/bash

# This script will be run in chroot under qemu.

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C
/var/lib/dpkg/info/dash.preinst install
dpkg --configure -a

groupadd volumio
useradd -c volumio -d /home/volumio -m -g volumio -G adm,dialout,cdrom,floppy,audio,dip,video,plugdev -s /bin/bash -p '$6$ZZZZZZZZ$WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW' volumio



echo "volumio ALL=(ALL) ALL" >> /etc/sudoers



cat > /etc/network/interfaces << EOF
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp

allow-hotplug wlan0

EOF
chmod 600 /etc/network/interfaces

echo volumio > /etc/hostname

echo "nameserver 8.8.8.8" > /etc/resolv.conf

# cleanup
apt-get clean

rm -rf tmp/*
rm configscript.sh 
