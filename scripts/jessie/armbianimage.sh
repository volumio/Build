#!/bin/sh

# Default build for Debian 32bit
ARCH="armv7"

while getopts ":d:v:p:" opt; do
  case $opt in
    d)
      DEVICE=$OPTARG
      ;;
    v)
      VERSION=$OPTARG
      ;;
    p)
      PATCH=$OPTARG
      ;;

  esac
done

old="$IFS"
set -f; IFS='_'
set -- $DEVICE
BOARD=$2
BRANCH=$3
set +f
IFS="$old"

echo "We're sorry, due to various failure reports and currently missing community support, Armbian builds had to be suspended"
exit 1

echo BOARD:$BOARD BRANCH:$BRANCH

BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-${DEVICE}.img"

if [ "$ARCH" = arm ]; then
  DISTRO="Raspbian"
else
  DISTRO="Debian 32bit"
fi

echo "Creating Image File ${IMG_FILE} with $DISTRO rootfs"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
# Note: leave the first 20Mb free for the firmware
parted -s "${LOOP_DEV}" mklabel msdos
# parted -s "${LOOP_DEV}" mkpart primary fat32 1 64
parted -s "${LOOP_DEV}" mkpart primary ext3 1 64
parted -s "${LOOP_DEV}" mkpart primary ext3 65 2500
parted -s "${LOOP_DEV}" mkpart primary ext3 2500 100%
parted -s "${LOOP_DEV}" set 1 boot on
parted -s "${LOOP_DEV}" print
partprobe "${LOOP_DEV}"
kpartx -s -a "${LOOP_DEV}"

BOOT_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
SYS_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
DATA_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p3`
echo "Using: " ${BOOT_PART}
echo "Using: " ${SYS_PART}
echo "Using: " ${DATA_PART}
if [ ! -b "${BOOT_PART}" ]
then
	echo "${BOOT_PART} doesn't exist"
	exit 1
fi

echo "Creating boot and rootfs filesystems"
# mkfs -t vfat -n BOOT "${BOOT_PART}"
mkfs -F -t ext4 -L BOOT "${BOOT_PART}"
mkfs -F -t ext4 -L volumio "${SYS_PART}"
mkfs -F -t ext4 -L volumio_data "${DATA_PART}"
sync

if [ -d /mnt ]
then
	echo "/mount folder exist"
else
	mkdir /mnt
fi
if [ -d /mnt/volumio ]
then
	echo "Volumio Temp Directory Exists - Cleaning it"
	rm -rf /mnt/volumio/*
else
	echo "Creating Volumio Temp Directory"
	sudo mkdir /mnt/volumio
fi

echo "Creating mount point for the images partition"
mkdir /mnt/volumio/images
mount -t ext4 "${SYS_PART}" /mnt/volumio/images
mkdir /mnt/volumio/rootfs
echo "Creating mount point for the boot partition"
mkdir /mnt/volumio/rootfs/boot
# mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot
mount -t ext4 "${BOOT_PART}" /mnt/volumio/rootfs/boot

echo "Copying Volumio RootFs"
cp -pdR build/arm/root/* /mnt/volumio/rootfs

echo "Preparing to run chroot for more BPI-PRO configuration"
cp scripts/armbianconfig.sh /mnt/volumio/rootfs
cp scripts/upgrade_armbian.sh /mnt/volumio/rootfs/root
cp scripts/initramfs/init_armbian  /mnt/volumio/rootfs/root/init
echo "BOARD=$BOARD\nBRANCH=$BRANCH\n" > /mnt/volumio/rootfs/root/device.sh
cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin
#copy the scripts for updating from usb
wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs
echo $PATCH > /mnt/volumio/rootfs/patch

chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/armbianconfig.sh
EOF

# write board specific boot sector
echo write board specific boot sector
dd if=/mnt/volumio/rootfs/boot/u-boot-sunxi-with-spl.bin of=${LOOP_DEV} bs=1024 seek=8 conv=notrunc

#cleanup
rm /mnt/volumio/rootfs/armbianconfig.sh /mnt/volumio/rootfs/root/init

echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys

#echo "Copying LIRC configuration files"


echo "==> BPI-PRO device installed"

#echo "Removing temporary platform files"
#echo "(you can keep it safely as long as you're sure of no changes)"
#rm -r platform-bananapi
sync

echo "Finalizing Rootfs creation"
sh scripts/finalize.sh

echo "Preparing rootfs base for SquashFS"

if [ -d /mnt/squash ]; then
	echo "Volumio SquashFS Temp Dir Exists - Cleaning it"
	rm -rf /mnt/squash/*
else
	echo "Creating Volumio SquashFS Temp Dir"
	mkdir /mnt/squash
fi

echo "Copying Volumio rootfs to Temp Dir"
cp -rp /mnt/volumio/rootfs/* /mnt/squash/

if [ -e /mnt/kernel_current.tar ]; then
	echo "Volumio Kernel Partition Archive exists - Cleaning it"
	rm -rf /mnt/kernel_current.tar
fi

echo "Creating Kernel Partition Archive"
tar cf /mnt/kernel_current.tar  -C /mnt/squash/boot/ .

echo "Removing the Kernel"
rm -rf /mnt/squash/boot/*

echo "Creating SquashFS, removing any previous one"
rm -r Volumio.sqsh
mksquashfs /mnt/squash/* Volumio.sqsh

echo "Squash filesystem created"
echo "Cleaning squash environment"
rm -rf /mnt/squash

#copy the squash image inside the boot partition
cp Volumio.sqsh /mnt/volumio/images/volumio_current.sqsh
sync
echo "Unmounting Temp Devices"
umount -l /mnt/volumio/images
umount -l /mnt/volumio/rootfs/boot

dmsetup remove_all
losetup -d ${LOOP_DEV}
sync

md5sum "$IMG_FILE" > "${IMG_FILE}.md5"
