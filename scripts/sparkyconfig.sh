#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.

echo "Creating \"fstab\""
echo "# sparky fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab

#echo "Adding default sound module"
#echo "snd-soc-allo-piano-dac-plus
#snd-soc-allo-piano-dac" >> /etc/modules

echo "Blacklisting noisy module"
echo "blacklist ctp_gsl3680" > /etc/modprobe.d/blacklist.conf

echo "Installing additonal packages"
apt-get update
apt-get -y install u-boot-tools

wget  https://raw.githubusercontent.com/sparkysbc/downloads/master/wiringSparky.tgz
tar -xzvf wiringSparky.tgz -C /
rm wiringSparky.tgz 

echo "Adding custom modules overlayfs, squashfs and nls_cp437"
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

echo "Changing to 'modules=dep'"
echo "(otherwise sparky may not boot due to size of initrd)"
sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf

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
mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/ramdisk.img
#TODO update uenv.txt to use uInitrd as the ramdisk name (like all other platforms)

echo "Removing unnecessary /boot files"
rm /boot/volumio.initrd
