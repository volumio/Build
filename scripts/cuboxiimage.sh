#!/bin/sh
IMG_FILE="Volumio.img"
 
echo "Creating Image Bed"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=1048
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
#sudo parted -s "${LOOP_DEV}p1" mkpart primary ext3 0 10
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 10 1048
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -a "${LOOP_DEV}"
 
LOOP_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p1`

if [ ! -b "$LOOP_PART" ]
then
	echo "$LOOP_PART doesn't exist"
	exit 1
fi

echo "Creating filesystems"
sudo mkfs.ext4 -E stride=2,stripe-width=1024 -b 4096 "${LOOP_PART}" -L volumio
sync
 
echo "Burning bootloader"
sudo dd if=platforms/cuboxi/uboot/u-boot.img of=${LOOP_DEV} bs=1K seek=42
echo "Burning SPL"
sudo dd if=platforms/cuboxi/uboot/SPL of=${LOOP_DEV} bs=1K seek=1
sync

 
echo "Copying Volumio RootFs"
sudo mkdir /mnt
sudo mkdir /mnt/volumio
sudo mount -t ext4 "${LOOP_PART}" /mnt/volumio
sudo rm -rf /mnt/volumio/*
sudo cp -r build/root/* /mnt/volumio
fi
sync

echo "Copying Kernel"
sudo cp -r platforms/cuboxi/boot /mnt/volumio/
 
echo "Copying Modules and Firmwares"
sudo cp -r platforms/cuboxi/lib/modules /mnt/volumio/lib/modules
sudo cp -r platforms/cuboxi/firmware /mnt/volumio/lib/firmware
sync
  
ls -al /mnt/volumio/
 
sudo umount /mnt/volumio/
 
echo
echo Umount
echo
sudo losetup -d ${LOOP_DEV}
