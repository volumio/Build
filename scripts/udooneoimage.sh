#!/bin/sh

while getopts ":v:p:" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
    p)
      PATCH=$OPTARG
      ;;

  esac
done

BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}UDOONEO.img"

 
echo "Creating Image Bed"
echo "Image file: ${IMG_FILE}"


dd if=/dev/zero of=${IMG_FILE} bs=1M count=1500
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 3 64
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 64 1220
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 1220 1500
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -a "${LOOP_DEV}" -s
 
BOOT_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
IMG_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
DATA_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p3`

if [ ! -b "$BOOT_PART" ]
then
	echo "$BOOT_PART doesn't exist"
	exit 1
fi

echo "Creating filesystems"
sudo mkfs.vfat "${BOOT_PART}" -n boot
sudo mkfs.ext4 -E stride=2,stripe-width=1024 -b 4096 "${IMG_PART}" -L volumio
sudo mkfs.ext4 -E stride=2,stripe-width=1024 -b 4096 "${DATA_PART}" -L data
sync
  
echo "Copying Volumio RootFs"
if [ -d /mnt ]; then 
	echo "/mnt/folder exist"
else
	sudo mkdir /mnt
fi

if [ -d /mnt/volumio ]; then 
	echo "Volumio Temp Directory Exists - Cleaning it"
	rm -rf /mnt/volumio/*
else
	echo "Creating Volumio Temp Directory"
	sudo mkdir /mnt/volumio
fi

#Create mount point for the images partition
sudo mkdir /mnt/volumio/rootfs
sudo mount -t ext4 "${IMG_PART}" /mnt/volumio/rootfs
sudo mkdir /mnt/volumio/rootfs/boot
sudo mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot
sudo cp -pdR build/arm/root/* /mnt/volumio/rootfs
sync

echo "Cloning UDOO NEO Files"
git clone https://github.com/volumio/platform-udooneo.git

echo "Copying U-boot"
sudo dd if=platform-udooneo/uboot/uboot-neo.imx of=${LOOP_DEV} bs=512 seek=2
cp -rp platform-udooneo/dts /mnt/volumio/rootfs/boot/dtsnew
echo "Cleaning UDOO NEO FIles"
rm -rf platform-udooneo

echo "Entering Chroot Environment"

cp scripts/udooneoconfig.sh /mnt/volumio/rootfs


# Commenting SquashFS part since NEO doesn't have squashfs + overlayfs available
#cp scripts/initramfs/init /mnt/volumio/rootfs/root
#cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin

#copy the scripts for updating from usb
#wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater 

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs
echo $PATCH > /mnt/volumio/rootfs/patch
chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/udooneoconfig.sh -p 
EOF

echo "Base System Installed"
#rm /mnt/volumio/rootfs/udooneoconfig.sh /mnt/volumio/rootfs/root/init
echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev 
umount -l /mnt/volumio/rootfs/proc 
umount -l /mnt/volumio/rootfs/sys 



echo "Copying Firmwares"

sync

#echo "Creating RootFS Base for SquashFS"
#
#if [ -d /mnt/squash ]; then
#	echo "Volumio SquashFS  Temp Directory Exists - Cleaning it"
#	rm -rf /mnt/squash/*
#else
#	echo "Creating Volumio SquashFS Temp Directory"
#	sudo mkdir /mnt/squash
#fi

#echo "Copying Volumio ROOTFS to Temp DIR"
#cp -rp /mnt/volumio/rootfs/* /mnt/squash/
#
#echo "Removing Kernel"
#rm -rf /mnt/squash/boot/*

#echo "Creating SquashFS"
#mksquashfs /mnt/squash/* Volumio.sqsh

#echo "Squash file system created"
#echo "Cleaning squash environment"
#rm -rf /mnt/squash

#copy the squash image inside the images partition
#cp Volumio.sqsh /mnt/volumio/images/volumio_current.sqsh

echo "Unmounting Temp Devices"
sudo umount -l /mnt/volumio/rootfs
sudo umount -l /mnt/volumio/rootfs/boot


echo "Cleaning build environment"
#rm -rf /mnt/volumio /mnt/boot

dmsetup remove_all
sudo losetup -d ${LOOP_DEV}
