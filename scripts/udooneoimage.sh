#!/bin/sh

# Default build for Debian 32bit
ARCH="armv7"

while getopts ":v:p:a:" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
    p)
      PATCH=$OPTARG
      ;;
    a)
      ARCH=$OPTARG
      ;;
  esac
done

BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-udooneo.img"

if [ "$ARCH" = arm ]; then
  DISTRO="Raspbian"
else
  DISTRO="Debian 32bit"
fi

echo "Creating Image File ${IMG_FILE} with $DISTRO rootfs"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`

parted -s "${LOOP_DEV}" mklabel msdos
parted -s "${LOOP_DEV}" mkpart primary fat32 1 64
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
mkfs -t vfat -n BOOT "${BOOT_PART}"
mkfs -F -t ext4 -L volumio "${SYS_PART}"
mkfs -F -t ext4 -L volumio_data "${DATA_PART}"
sync

echo "Preparing for the udoo kernel/ platform files"
if [ -d platform-udoo ]
then
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the platforms-udoo folder
	cd platform-udoo
        tar xfJ udoo-neo.tar.xz
	tar xfJ udoo-qdl.tar.xz
        cd ..

else
	echo "Clone all UDOO files from repo"
	git clone --depth 1 https://github.com/volumio/platform-udoo.git platform-udoo
	echo "Unpack the UDOO  platform files"
    cd platform-udoo
	tar xfJ udoo-neo.tar.xz
	cd ..
fi

#TODO: Check!!!!
echo "Copying the bootloader"
echo "Burning bootloader"
dd if=platform-udoo/udoo-neo/uboot/SPL of=${LOOP_DEV} bs=1K seek=1
dd if=platform-udoo/udoo-neo/uboot/u-boot.img of=${LOOP_DEV} bs=1K seek=69
sync

echo "Preparing for Volumio rootfs"
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
	mkdir /mnt/volumio
fi

echo "Creating mount point for the images partition"
mkdir /mnt/volumio/images
mount -t ext4 "${SYS_PART}" /mnt/volumio/images
mkdir /mnt/volumio/rootfs
mkdir /mnt/volumio/rootfs/boot
mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot

echo "Copying Volumio RootFs"
cp -pdR build/$ARCH/root/* /mnt/volumio/rootfs
echo "Copying udoo-neo boot files, Kernel, Modules and Firmware"
cp -R platform-udoo/udoo-neo/boot/* /mnt/volumio/rootfs/boot
cp -pdR platform-udoo/udoo-neo/lib/modules /mnt/volumio/rootfs/lib
cp -pdR platform-udoo/udoo-neo/lib/firmware /mnt/volumio/rootfs/lib


#TODO: asound.conf (/etc/) and asound.state (/var/lib/alsa/)
sync

echo "Preparing to run chroot for more udoo-neo configuration"
cp scripts/udooneoconfig.sh /mnt/volumio/rootfs
cp scripts/initramfs/init /mnt/volumio/rootfs/root
cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin
#copy the scripts for updating from usb
wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs
echo $PATCH > /mnt/volumio/rootfs/patch
chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/udooneoconfig.sh
EOF

#cleanup
rm /mnt/volumio/rootfs/udooneoconfig.sh /mnt/volumio/rootfs/root/init

echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys

echo "==> udoo-neo device installed"

#echo "Removing temporary platform files"
#echo "(you can keep it safely as long as you're sure of no changes)"
#sudo rm -r platforms-udoo
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
tar cf /mnt/kernel_current.tar --exclude='resize-volumio-datapart' -C /mnt/squash/boot/ .

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
