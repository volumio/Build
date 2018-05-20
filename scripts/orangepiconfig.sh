#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.

echo "Creating \"fstab\""
echo "# OrangePi fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab

#echo "Adding default sound modules and wifi"
#echo "sunxi_codec
#sunxi_i2s
#sunxi_sndcodec
#8723bs
#" >> /etc/modules

#echo "Blacklisting 8723bs_vq0"
#echo "blacklist 8723bs_vq0" >> /etc/modprobe.d/blacklist-pine64.conf

apt-get update
apt-get -y install u-boot-tools liblircclient0 lirc aptitude bc

echo "Installing additonal packages"
apt-get install -qq -y dialog debconf-utils lsb-release aptitude

echo "Adding custom modules overlayfs, squashfs and nls_cp437"
echo "overlay" >> /etc/initramfs-tools/modules
echo "overlayfs" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules
echo "nls_cp437" >> /etc/initramfs-tools/modules

echo "Copying volumio initramfs updater"
cd /root/
mv volumio-init-updater /usr/local/sbin

#On The Fly Patch
if [ "$PATCH" = "volumio" ]; then
echo "No Patch To Apply"
else
echo "Applying Patch ${PATCH}"
PATCHPATH=/${PATCH}
cd $PATCHPATH
#Check the existence of patch script
if [ -f "patch.sh" ]; then
sh patch.sh
else
echo "Cannot Find Patch File, aborting"
fi
cd /
rm -rf ${PATCH}
fi
rm /patch

echo "Installing winbind here, since it freezes networking"
apt-get update
apt-get install -y winbind libnss-winbind

echo "adding gpio group and udev rules"
groupadd -f --system gpio
usermod -aG gpio volumio
touch /etc/udev/rules.d/99-gpio.rules
echo "SUBSYSTEM==\"gpio\", ACTION==\"add\", RUN=\"/bin/sh -c '
        chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio;\
        chown -R root:gpio /sys$DEVPATH && chmod -R 770 /sys$DEVPATH\
'\"" > /etc/udev/rules.d/99-gpio.rules

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

#First Boot operations
echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart

echo "Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp

echo "Creating uInitrd from 'volumio.initrd'"
mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
mkimage -A arm -T script -C none -d /boot/boot.cmd /boot/boot.scr
echo "Cleaning up"
# rm /boot/volumio.initrd
