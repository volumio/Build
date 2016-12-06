#!/bin/bash

while getopts ":v:" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
  esac
done

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.

echo "Creating Fstab File"

touch /etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000,noauto,nofail        0       1
/dev/mmcblk0p2  /               ext4    defaults,noatime               0  0
/dev/mmcblk0p3  /data           ext4    defaults,noatime,noauto,nofail               0  0
tmpfs   /var/log                tmpfs   size=20M,nodev 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
" > /etc/fstab

echo "Adding UDOO's Repo Key"
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 71F0E740

echo "Adding UDOO's Repository"
echo "deb http://repository.udoo.org udoobuntu main" >> /etc/apt/sources.list

echo "Installing Kernel"
apt-get update
apt-get -y install linux-3.14.56-udooneo

echo "Applying Custom DTS"
rm -rf /boot/dts
mv /boot/dtsnew /boot/dts

echo "Installing Firmware and Modules"
apt-get -y install firmware-udooneo-wl1831 udev-udooneo-rules udooneo-bluetooth


#echo "Adding volumio-remote-updater"
#wget -P /usr/local/bin/ http://updates.volumio.org/jx
#wget -P /usr/local/sbin/ http://updates.volumio.org/volumio-remote-updater.jx
#chmod +x /usr/local/sbin/volumio-remote-updater.jx /usr/local/bin/jx

echo "Cleaning APT Cache"
rm -f /var/lib/apt/lists/*archive*
apt-get clean

#echo "Adding custom modules"
#echo "squashfs" >> /etc/initramfs-tools/modules
#echo "overlay" >> /etc/initramfs-tools/modules


#compile the volumio-init-updater
#echo "Compiling volumio initramfs updater"
#cd /root/
#mv volumio-init-updater /usr/local/sbin

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


#echo "Creating initramfs"
#mkinitramfs-custom.sh -o /tmp/initramfs-tmp
