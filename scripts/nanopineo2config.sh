#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.

echo "Creating \"fstab\""
echo "# NanoPi-NEO 2 fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab

ARCH=$(cat /etc/os-release | grep ^VOLUMIO_ARCH | tr -d 'VOLUMIO_ARCH="')
echo $ARCH

if [ $ARCH = armv7 ]; then
  echo "Armv7 Environment detected"
  echo "#!/bin/sh
sysctl abi.cp15_barrier=2
" > /usr/local/bin/nanopineo2-init.sh
  chmod +x /usr/local/bin/nanopineo2-init.sh

  echo "#!/bin/sh -e
  /usr/local/bin/nanopineo2-init.sh
  exit 0" > /etc/rc.local
fi

#echo "Adding default sound modules and wifi"
#echo "sunxi_codec
#sunxi_i2s
#sunxi_sndcodec
#8723bs
#" >> /etc/modules

#echo "Blacklisting 8723bs_vq0"
#echo "blacklist 8723bs_vq0" >> /etc/modprobe.d/blacklist-nanopineo2.conf

echo "Installing additonal packages"
#apt-get update
#apt-get -y install u-boot-tools liblircclient0 lirc

# echo "Cleaning APT Cache and remove policy file"
# rm -f /var/lib/apt/lists/*archive*
# apt-get clean

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


#echo "Changing to 'modules=dep'"
#echo "(otherwise NanoPi-NEO2 won't boot due to uInitrd 4MB limit)"
#sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf

echo "Installing winbind here, since it freezes networking"
apt-get update
apt-get install -y winbind libnss-winbind

# echo "Install e2fsporgs from stretch"
# # apt-get remove -y e2fsprogs
# echo "deb http://deb.debian.org/debian stretch main" | sudo tee /etc/apt/sources.list.d/stretch.list
# apt-get update && apt-get install -y e2fsprogs
# sudo rm -f /etc/apt/sources.list.d/stretch.list

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

#First Boot operations
echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart

echo "Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp
