#!/bin/bash

# This script will be run in chroot under qemu.

echo "Creating Fstab File"

touch /etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0 
tmpfs   /var/cache/apt/archives tmpfs   defaults,noexec,nosuid,nodev,mode=0755 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
" > /etc/fstab

# echo "Writing cmdline file"
# echo "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait" > /boot/cmdline.txt

echo "Adding BCM Module"

echo "
snd_bcm2835
" >> /etc/modules

echo "Installing Kernel from Rpi-Update"

apt-get update
apt-get -y install git-core binutils ca-certificates curl busybox parted
sudo curl -L --output /usr/bin/rpi-update https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update && sudo chmod +x /usr/bin/rpi-update
touch /boot/start.elf
mkdir /lib/modules
mkdir /lib/firmware
# Kernel Commit https://github.com/Hexxeh/rpi-firmware/commit/38aa676b044f8de46aedb4bd972538a7ad6a3ce1
#SKIP_BACKUP=1 rpi-update 38aa676b044f8de46aedb4bd972538a7ad6a3ce1

# Kernel 4.0.6 for i2s compatibility  
echo y | SKIP_BACKUP=1 rpi-update a51e2e072f2c349b40887dbdb8029f9a78c01987

# echo "Writing cmdline file"
# echo "dwc_otg.fiq_enable=1 dwc_otg.fiq_fsm_enable=1 dwc_otg.fiq_fsm_mask=0x3 dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait" > /boot/cmdline.txt

echo "Adding volumio-remote-updater"
wget -P /usr/local/sbin/ http://repo.volumio.org/Volumio2/Binaries/volumio-remote-updater

echo "Cleaning APT Cache"
rm -f /var/lib/apt/lists/*archive*
apt-get clean

echo "Adding custom modules"
echo "squashfs" >> /etc/initramfs-tools/modules
echo "overlay" >> /etc/initramfs-tools/modules
cat /etc/initramfs-tools/modules

#compile the volumio-init-updater
echo "Compiling volumio initramfs updater"
cd /root/
mv volumio-init-updater /usr/local/sbin

echo "Creating initramfs"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp
