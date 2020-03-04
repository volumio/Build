#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.
echo "Initializing.."
. init.sh

echo "Creating \"fstab\""
echo "# Amlogic fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
LABEL=BOOT /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab

echo "#!/bin/sh -e
/etc/hdmi.sh &
/etc/fan.sh &
exit 0" > /etc/rc.local

echo "Adding default sound modules and wifi"
echo "dhd
snd_soc_pcm5102
snd_soc_odroid_dac
" >> /etc/modules

echo "Installing additonal packages"
apt-get update
apt-get -y install u-boot-tools liblircclient0 lirc mc abootimg fbset

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

#echo "Changing to 'modules=dep'"
#echo "(otherwise won't boot due to uInitrd 4MB limit)"
#sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf

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

echo "Creating s905_autoscript"
mkimage -A arm -O linux -T script -C none -d /boot/s905_autoscript.cmd /boot/s905_autoscript

echo "Removing unnecessary /boot files"
rm /boot/volumio.initrd
