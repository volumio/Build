#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.
echo "Initializing.."
. init.sh

echo "Creating \"fstab\""
echo "# Amlogic fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
UUID=${UUID_BOOT} /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab

sed -i "s/#imgpart=UUID=/imgpart=UUID=${UUID_IMG}/g" /boot/env.system.txt
sed -i "s/#bootpart=UUID=/bootpart=UUID=${UUID_BOOT}/g" /boot/env.system.txt
sed -i "s/#datapart=UUID=/datapart=UUID=${UUID_DATA}/g" /boot/env.system.txt

echo "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
echo "abi.cp15_barrier=2" >> /etc/sysctl.conf
echo "Remove default dmesg restriction"
echo "kernel.dmesg_restrict = 0" >> /etc/sysctl.conf

echo "Adding default wifi"
echo "dhd
" >> /etc/modules

echo "USB Card Ordering"
echo "
# USB DACs will have device number 5 in whole Volumio device range
options snd-usb-audio index=5" >> /etc/modprobe.d/alsa-base.conf

echo "Installing additional packages"
apt-get update
apt-get -y install u-boot-tools mc abootimg fbset bluez-firmware bluetooth bluez bluez-tools device-tree-compiler linux-base

echo "Enabling KVIM Bluetooth stack"
ln -sf /lib/firmware /etc/firmware
ln -s /lib/systemd/system/bluetooth-khadas.service /etc/systemd/system/multi-user.target.wants/bluetooth-khadas.service
if [ ! "$MODEL" = kvim1 ]; then
	ln -s /lib/systemd/system/fan.service /etc/systemd/system/multi-user.target.wants/fan.service
fi

echo "Configuring boot splash"
apt-get -y install plymouth plymouth-themes
plymouth-set-default-theme volumio

echo "Installing Kiosk"
sh /install-kiosk.sh

echo "Kiosk installed"
rm /install-kiosk.sh

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean

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
if [ -f "install.sh" ]; then
sh install.sh
fi
cd /
rm -rf ${PATCH}
fi
rm /patch

#echo "Changing to 'modules=list' to reduce the size of uInitrd"
sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf

echo "Installing winbind here, since it freezes networking"
apt-get update
apt-get install -y winbind libnss-winbind

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
mkimage -A arm64 -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd

echo "Removing unnecessary /boot files"
rm /boot/volumio.initrd
