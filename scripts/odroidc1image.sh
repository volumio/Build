#!/bin/sh

while getopts ":v:" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
  esac
done
BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}OdroidC1.img"

 
echo "Creating Image Bed"
echo "Image file: ${IMG_FILE}"


dd if=/dev/zero of=${IMG_FILE} bs=1M count=4000
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 1 64
sudo parted -s "${LOOP_DEV}" mkpart primary ext4 65 2113
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -a "${LOOP_DEV}"
 
BOOT_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
SYS_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
echo "Using: " ${BOOT_PART}
echo "Using: " ${SYS_PART}
#if [ ! -b "${BOOT_PART}" ]
#then
#	echo "${BOOT_PART} doesn't exist"
#	exit 1
#fi
#
#if [ ! -b "${SYS_PART}" ]
#then
#	echo "${SYS_PART} doesn't exist"
#	exit 1
#fi

echo "Creating filesystems"
sudo mkfs -t vfat -n BOOT "${BOOT_PART}"
sudo mkfs -F -t ext4 -L volumio "${SYS_PART}"
sync

echo "Copying the bootloader"
sudo dd if=platforms/odroidc1/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=1 count=442
sudo dd if=platforms/odroidc1/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=512 skip=1 seek=1
sudo dd if=platforms/odroidc1/uboot/u-boot.bin of=${LOOP_DEV} seek=64
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
sudo cp -pdR build/arm/root/* /mnt/volumio
sudo cp platforms/odroidc1/boot/boot.ini /mnt/volumio/boot
sudo cp platforms/odroidc1/boot/meson8b_odroidc.dtb /mnt/volumio/boot
sudo cp platforms/odroidc1/boot/uImage /mnt/volumio/boot
sudo cp platforms/odroidc1/boot/uInitrd /mnt/volumio/boot

sync

echo "Entering Chroot Environment"

#cp scripts/odroidc1config.sh /mnt/volumio
mount /dev /mnt/volumio/dev -o bind
mount /proc /mnt/volumio/proc -t proc
mount /sys /mnt/volumio/sys -t sysfs
chroot /mnt/volumio /bin/bash -x <<'EOF'
su -
/odroidc1config.sh
EOF

echo "Base System Installed"
rm /mnt/volumio/odroidconfig.sh
echo "Unmounting Temp devices"
umount -l /mnt/volumio/dev 
umount -l /mnt/volumio/proc 
umount -l /mnt/volumio/sys 

echo "Copying Firmwares"

sync
  
ls -al /mnt/volumio/
 
echo "Unmounting Temp Devices"
sudo umount -l /mnt/volumio/boot
sudo umount -l /mnt/volumio/
sudo dmsetup remove_all
sudo losetup -d ${LOOP_DEV}


