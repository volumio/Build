#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.
echo "Initializing.."
. init.sh

echo "Creating \"fstab\""
echo "# ROCK64 fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
UUID=${UUID_BOOT} /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab

echo "Creating boot config"
echo "label kernel-4.4
    kernel /Image
    fdt /rk3328-rock64.dtb
    initrd /uInitrd
    append  earlycon=uart8250,mmio32,0xff130000 imgpart=UUID=${UUID_IMG} imgfile=/volumio_current.sqsh hwdevice=Rock64 bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA} bootconfig=/extlinux/extlinux.conf
"> /boot/extlinux/extlinux.conf

echo "#!/bin/sh
sysctl abi.cp15_barrier=2
" > /usr/local/bin/rock64-init.sh

chmod +x /usr/local/bin/rock64-init.sh
chmod +x /usr/local/sbin/enable_dtoverlay

echo "#!/bin/sh -e
/usr/local/bin/rock64-init.sh
exit 0" > /etc/rc.local

echo "Installing additonal packages"
apt-get update
apt-get -y install device-tree-compiler u-boot-tools liblircclient0 lirc

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean

echo "Adding custom modules overlay, squashfs and nls_cp437"
echo "overlay" >> /etc/initramfs-tools/modules
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
echo "(otherwise Odroid won't boot due to uInitrd 4MB limit)"
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

echo "Creating uImage from 'volumio.initrd'"
mkimage -A arm64 -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd

echo "Removing unnecessary /boot files"
rm /boot/volumio.initrd
