#!/bin/sh

# This script will be run in chroot under qemu.

echo "Creating Fstab File"

touch etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults        0       0
" > etc/fstab

echo "Writing cmdline file"
echo "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait" > boot/cmdline.txt

echo "Adding BCM Module"

echo "
snd_bcm2835
" >> etc/modules

