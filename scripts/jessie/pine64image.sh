#!/bin/sh

# Build Architecture Debian 32bit (to be changed to armv8)
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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-pine64.img"

if [ "$ARCH" = arm ]; then
  DISTRO="Raspbian"
else
  DISTRO="Debian 32bit"
fi

echo "Creating Image File ${IMG_FILE} with ${DISTRO} rootfs"

dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
# Note: leave the first 20Mb free for the firmware
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 21 84
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 84 2500
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 2500 100%
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -s -a "${LOOP_DEV}"

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
sudo mkfs -t vfat -n BOOT "${BOOT_PART}"
sudo mkfs -F -t ext4 -L volumio "${SYS_PART}"
sudo mkfs -F -t ext4 -L volumio_data "${DATA_PART}"
sync

echo "Preparing for the (so)Pine64(LTS) kernel/ platform files"
if [ -d platform-pine64 ]
then
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the platform-pine64 folder
    # that will refresh all the odroid platforms, see below
else
	echo "Clone (so)Pine64(LTS) files from repo"
	git clone --depth 1 https://github.com/volumio/platform-pine64.git platform-pine64
	echo "Unpack the platform files"
    cd platform-pine64
	tar xfJ sopine64lts.tar.xz
	cd ..
fi

echo "Copying the Pine64 bootloader"
sudo dd if=platform-pine64/sopine64/u-boot/boot0.bin of=${LOOP_DEV} conv=notrunc bs=1k seek=8
sudo dd if=platform-pine64/sopine64/u-boot/u-boot-with-dtb.bin of=${LOOP_DEV} conv=notrunc bs=1k seek=19096
sync

echo "Preparing for Volumio rootfs"
if [ -d /mnt ]
then
	echo "/mount folder exist"
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

echo "Creating mount point for the images partition"
mkdir /mnt/volumio/images
sudo mount -t ext4 "${SYS_PART}" /mnt/volumio/images
sudo mkdir /mnt/volumio/rootfs
sudo mkdir /mnt/volumio/rootfs/boot
sudo mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot

echo "Copying Volumio RootFs"
sudo cp -pdR build/$ARCH/root/* /mnt/volumio/rootfs
echo "Copying (so)Pine64(LTS) boot files"
mkdir /mnt/volumio/rootfs/boot/pine64
sudo cp platform-pine64/sopine64/boot/pine64/Image /mnt/volumio/rootfs/boot/pine64
sudo cp platform-pine64/sopine64/boot/pine64/*.dtb /mnt/volumio/rootfs/boot/pine64
sudo cp platform-pine64/sopine64/boot/uEnv.txt /mnt/volumio/rootfs/boot
sudo cp platform-pine64/sopine64/boot/Image.version /mnt/volumio/rootfs/boot
sudo cp platform-pine64/sopine64/boot/config* /mnt/volumio/rootfs/boot

echo "Copying (so)Pine64(LTS) modules and firmware"
sudo cp -pdR platform-pine64/sopine64/lib/modules /mnt/volumio/rootfs/lib/
sudo cp -pdR platform-pine64/sopine64/lib/firmware /mnt/volumio/rootfs/lib/

echo "Confguring ALSA with sane defaults"
sudo cp platform-pine64/sopine64/var/lib/alsa/* /mnt/volumio/rootfs/var/lib/alsa

sync

echo "Preparing to run chroot for more pine64 configuration"
cp scripts/pine64config.sh /mnt/volumio/rootfs
cp scripts/initramfs/init /mnt/volumio/rootfs/root
cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin
#copy the scripts for updating from usb
wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs

echo $PATCH > /mnt/volumio/rootfs/patch

if [ -f "/mnt/volumio/rootfs/$PATCH/patch.sh" ] && [ -f "config.js" ]; then
        if [ -f "UIVARIANT" ] && [ -f "variant.js" ]; then
                UIVARIANT=$(cat "UIVARIANT")
                echo "Configuring variant $UIVARIANT"
                echo "Starting config.js for variant $UIVARIANT"
                node config.js $PATCH $UIVARIANT
                echo $UIVARIANT > /mnt/volumio/rootfs/UIVARIANT
        else
                echo "Starting config.js"
                node config.js $PATCH
        fi
fi

chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/pine64config.sh
EOF

UIVARIANT_FILE=/mnt/volumio/rootfs/UIVARIANT
if [ -f "${UIVARIANT_FILE}" ]; then
    echo "Starting variant.js"
    node variant.js
    rm $UIVARIANT_FILE
fi

#cleanup
rm /mnt/volumio/rootfs/pine64config.sh /mnt/volumio/rootfs/root/init

echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys

#echo "Copying LIRC configuration files"
#sudo cp platform-pine64/pine64/etc/lirc/lircd.conf /mnt/volumio/rootfs/etc/lirc
#sudo cp platform-pine64/pine64/etc/lirc/hardware.conf /mnt/volumio/rootfs/etc/lirc
#sudo cp platform-pine64/pine64/etc/lirc/lircrc /mnt/volumio/rootfs/etc/lirc

echo "==> Pine64 device installed"

#echo "Removing temporary platform files"
#echo "(you can keep it safely as long as you're sure of no changes)"
#sudo rm -r platform-pine64
sync

echo "Finalizing Rootfs creation"
sh scripts/finalize.sh

echo "Preparing rootfs base for SquashFS"

if [ -d /mnt/squash ]; then
	echo "Volumio SquashFS Temp Dir Exists - Cleaning it"
	rm -rf /mnt/squash/*
else
	echo "Creating Volumio SquashFS Temp Dir"
	sudo mkdir /mnt/squash
fi

echo "Copying Volumio rootfs to Temp Dir"
cp -rp /mnt/volumio/rootfs/* /mnt/squash/

if [ -e /mnt/kernel_current.tar.gz ]; then
	echo "Volumio Kernel Partition Archive exists - Cleaning it"
	rm -rf /mnt/kernel_current.tar.gz
fi

echo "Creating Kernel Partition Archive"
tar cf /mnt/kernel_current.tar.gz --exclude='resize-volumio-datapart' -C /mnt/squash/boot/ .

echo "Removing the Kernel"
rm -rf /mnt/squash/boot/*

echo "Creating SquashFS, removing any previous one"
if [ -e Volumio.sqsh ]; then
	echo "Volumio Kernel Partition Archive exists - Cleaning it"
	rm -r Volumio.sqsh
fi

echo "Creating SquashFS"
mksquashfs /mnt/squash/* Volumio.sqsh

echo "Squash filesystem created"
echo "Cleaning squash environment"
rm -rf /mnt/squash

#copy the squash image inside the boot partition
cp Volumio.sqsh /mnt/volumio/images/volumio_current.sqsh
sync
echo "Unmounting Temp Devices"
sudo umount -l /mnt/volumio/images
sudo umount -l /mnt/volumio/rootfs/boot

sudo dmsetup remove_all
sudo losetup -d ${LOOP_DEV}
sync

md5sum "$IMG_FILE" > "${IMG_FILE}.md5"
