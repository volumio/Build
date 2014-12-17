#!/bin/sh
#Volumio Image Builder
#
#
echo "Executing Multistrap"
echo "Building Base Jessie System"
mkdir build
mkdir build/root
multistrap -a armhf -f conf/minimal.conf
cp /usr/bin/qemu-arm-static build/root/usr/bin/
cp firstconfig.sh build/root
mount /dev build/root/dev -o bind
mount /proc build/root/proc -t proc
mount /sys build/root/sys -t sysfs
chroot build/root /bin/bash -x <<'EOF'
su -
./firstconfig.sh


