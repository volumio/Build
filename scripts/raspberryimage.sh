#!/bin/sh

while getopts ":v:" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
  esac
done
BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}PI.img"

 
echo "Creating Image Bed"
echo "Image file: ${IMG_FILE}"


dd if=/dev/zero of=${IMG_FILE} bs=1M count=3548
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 0 64
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 65 3548
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -a "${LOOP_DEV}"
 
BOOT_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
SYS_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
if [ ! -b "$BOOT_PART" ]
then
	echo "$BOOT_PART doesn't exist"
	exit 1
fi

echo "Creating filesystems"
sudo mkfs.vfat "${BOOT_PART}" -n boot
sudo mkfs.ext4 -E stride=2,stripe-width=1024 -b 4096 "${SYS_PART}" -L volumio
sync
  
echo "Copying Volumio RootFs"
if [ -d /mnt ]
then 
echo "/mnt/folder exist"
else
sudo mkdir /mnt
fi
if [ -d /mnt/volumio ]
then 
echo "Volumio Temp Directory Exists - Cleaning it"
rm -rf /mnt/volumio/*
else
echo "Creating Volumio Temp Directory"
sudo mkdir /mnt/volumio
fi
sudo mount -t ext4 "${SYS_PART}" /mnt/volumio
sudo mkdir /mnt/volumio/boot
sudo mount -t vfat "${BOOT_PART}" /mnt/volumio/boot
sudo cp -pdR build/root/* /mnt/volumio
sync

echo "Entering Chroot Environment"

cp scripts/raspberryconfig.sh /mnt/volumio
mount /dev /mnt/volumio/dev -o bind
mount /proc /mnt/volumio/proc -t proc
mount /sys /mnt/volumio/sys -t sysfs
chroot /mnt/volumio /bin/bash -x <<'EOF'
su -
/raspberryconfig.sh
EOF

echo "Base System Installed"
rm /mnt/volumio/raspberryconfig.sh
echo "Unmounting Temp devices"
umount -l /mnt/volumio/dev 
umount -l /mnt/volumio/proc 
umount -l /mnt/volumio/sys 



echo "Copying Firmwares"

sync
  
ls -al /mnt/volumio/
 
echo "Unmounting Temp Devices"
sudo umount -l /mnt/volumio/
dmsetup remove_all
sudo losetup -d ${LOOP_DEV}

