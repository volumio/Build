#!/bin/bash

# This script will be run in chroot under qemu.

echo "Creating Fstab File"

touch /etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
/dev/mmcblk0p2  /               ext4    defaults,noatime,nodiratime  0   2
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0 
tmpfs   /var/cache/apt/archives tmpfs   defaults,noexec,nosuid,nodev,mode=0755 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
" > /etc/fstab

echo "Writing cmdline file"
echo "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait" > /boot/cmdline.txt

echo "Adding BCM Module"

echo "
snd_bcm2835
" >> /etc/modules

echo "Installing Kernel from Rpi-Update"

apt-get update
apt-get -y install git-core binutils ca-certificates curl
sudo curl -L --output /usr/bin/rpi-update https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update && sudo chmod +x /usr/bin/rpi-update
touch /boot/start.elf
mkdir /lib/modules
mkdir /lib/firmware
# Kernel Commit https://github.com/Hexxeh/rpi-firmware/commit/38aa676b044f8de46aedb4bd972538a7ad6a3ce1
SKIP_BACKUP=1 rpi-update 38aa676b044f8de46aedb4bd972538a7ad6a3ce1

echo "Writing cmdline file"
echo "dwc_otg.fiq_enable=1 dwc_otg.fiq_fsm_enable=1 dwc_otg.fiq_fsm_mask=0x3 dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait" > /boot/cmdline.txt


echo "Cleaning APT Cache"
apt-get clean
