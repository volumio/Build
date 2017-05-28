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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-pi.img"


echo "Creating Image Bed"
echo "Image file: ${IMG_FILE}"


dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`

sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 0 64
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 64 2500
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 2500 2800
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
#sudo mkfs.vfat "${BOOT_PART}" -n boot
# Using mkdosfs because pi seems to be picky with first partition block size
mkdosfs -n boot -F 32 -v "${BOOT_PART}"
sudo mkfs.ext4 -E stride=2,stripe-width=1024 -b 4096 "${IMG_PART}" -L volumio
sudo mkfs.ext4 -E stride=2,stripe-width=1024 -b 4096 "${DATA_PART}" -L volumio_data
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
sudo mkdir /mnt/volumio/images
sudo mount -t ext4 "${IMG_PART}" /mnt/volumio/images
sudo mkdir /mnt/volumio/rootfs
sudo cp -pdR build/arm/root/* /mnt/volumio/rootfs
#sudo mkdir /mnt/volumio/boot
sudo mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot

sync

echo "Entering Chroot Environment"

cp scripts/raspberryconfig.sh /mnt/volumio/rootfs

cp scripts/initramfs/init /mnt/volumio/rootfs/root
cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs

echo "Custom dtoverlay pre and post"
mkdir -p /mnt/volumio/rootfs/opt/vc/bin/
cp -rp volumio/opt/vc/bin/* /mnt/volumio/rootfs/opt/vc/bin/

echo $PATCH > /mnt/volumio/rootfs/patch
chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/raspberryconfig.sh -p
EOF

echo "Base System Installed"
rm /mnt/volumio/rootfs/raspberryconfig.sh /mnt/volumio/rootfs/root/init
echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys



echo "Copying Firmwares"

sync

echo "Creating RootFS Base for SquashFS"

if [ -d /mnt/squash ]; then
	echo "Volumio SquashFS  Temp Directory Exists - Cleaning it"
	rm -rf /mnt/squash/*
else
	echo "Creating Volumio SquashFS Temp Directory"
	sudo mkdir /mnt/squash
fi

echo "Copying Volumio ROOTFS to Temp DIR"
cp -rp /mnt/volumio/rootfs/* /mnt/squash/

echo "Removing Kernel"
rm -rf /mnt/squash/boot/*

echo "Deleting Volumio.sqsh from an earlier session"
rm Volumio.sqsh
echo "Creating SquashFS"
mksquashfs /mnt/squash/* Volumio.sqsh

echo "Squash file system created"
echo "Cleaning squash environment"
rm -rf /mnt/squash

#copy the squash image inside the images partition
cp Volumio.sqsh /mnt/volumio/images/volumio_current.sqsh

echo "Unmounting Temp Devices"
sudo umount -l /mnt/volumio/images
sudo umount -l /mnt/volumio/rootfs/boot

echo "Cleaning build environment"
rm -rf /mnt/volumio /mnt/boot

dmsetup remove_all
sudo losetup -d ${LOOP_DEV}
