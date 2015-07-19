#!/bin/sh

while getopts ":v:" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
  esac
done
BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-OdroidC1.img"

 
if [ -f ${IMG_FILE} ]
then
echo "Image file: ${IMG_FILE} exists, re-using"
else
echo "Creating Image File"
echo "Image file: ${IMG_FILE}"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=4000
fi

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 1 64
sudo parted -s "${LOOP_DEV}" mkpart primary ext4 65 2113
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -s -a "${LOOP_DEV}"

BOOT_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
SYS_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
echo "Using: " ${BOOT_PART}
echo "Using: " ${SYS_PART}
if [ ! -b "${BOOT_PART}" ]
then
	echo "${BOOT_PART} doesn't exist"
	exit 1
fi

if [ ! -b "${SYS_PART}" ]
then
	echo "${SYS_PART} doesn't exist"
	exit 1
fi

echo "Creating filesystems"
sudo mkfs -t vfat -n BOOT "${BOOT_PART}"
sudo mkfs -F -t ext4 -L volumio "${SYS_PART}"
sync

echo "Copying the bootloader"
sudo dd if=platforms/odroidc/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=1 count=442
sudo dd if=platforms/odroidc/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=512 skip=1 seek=1
sudo dd if=platforms/odroidc/uboot/u-boot.bin of=${LOOP_DEV} seek=64
sync

# change the UUID from boot and rootfs partion
#tune2fs ${BOOT_PART} -U CF56-1F80
#tune2fs ${SYS_PART} -U f87b8078-de6f-431d-b737-f122b015621c
# switch off journaling on ext4 (prevents excessiv wear on the card)
tune2fs -O ^has_journal ${SYS_PART}


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
echo "Copying rootfs"
sudo mount -t ext4 "${SYS_PART}" /mnt/volumio
sudo mkdir /mnt/volumio/boot
sudo mount -t vfat "${BOOT_PART}" /mnt/volumio/boot
sudo cp -pdR build/arm/root/* /mnt/volumio

echo "Copying boot files"
sudo cp platforms/odroidc/boot/boot.ini /mnt/volumio/boot
sudo cp platforms/odroidc/boot/meson8b_odroidc.dtb /mnt/volumio/boot
sudo cp platforms/odroidc/boot/uImage /mnt/volumio/boot
sudo cp platforms/odroidc/boot/uInitrd /mnt/volumio/boot

echo "Copying modules and firmware"
sudo cp -pdR platforms/odroidc/lib/modules /mnt/volumio/lib/
sudo cp -pdR platforms/odroidc/lib/firmware /mnt/volumio/lib/

echo "Copy inittab"
sudo cp platforms/odroidc/etc/inittab /mnt/volumio/etc/
sync

# ***************
# Create fstab
# ***************
echo "Creating \"fstab\""
echo "# Odroid fstab" > /mnt/volumio/etc/fstab
echo "" >> /mnt/volumio/etc/fstab
echo "/dev/mmcblk0p2  /        ext4    errors=remount-ro,rw,noatime,nodiratime 0 1" >> /mnt/volumio/etc/fstab 
echo "/dev/mmcblk0p1  /boot    vfat    defaults,ro,owner,flush,umask=000       0 0" >> /mnt/volumio/etc/fstab
echo "tmpfs           /tmp     tmpfs   nodev,nosuid,mode=1777                  0 0" >> /mnt/volumio/etc/fstab 

echo "Odroid-C device installed" 
  
ls -al /mnt/volumio/
 
echo "Unmounting Temp Devices"
sudo umount -l /mnt/volumio/boot
sudo umount -l /mnt/volumio/
sudo dmsetup remove_all
sudo losetup -d ${LOOP_DEV}
sync
