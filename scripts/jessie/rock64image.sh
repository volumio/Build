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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-rock64.img"

if [ "$ARCH" = arm ]; then
  DISTRO="Raspbian"
else
  DISTRO="Debian 32bit"
fi

echo "Creating Image File ${IMG_FILE} with ${DISTRO} rootfs"

dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
# Note: leave the first 20Mb free for the firmware (effectively needs ~16Mb)
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 20 84
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

echo "Preparing for the rock64 kernel/ platform files"
if [ -d platform-rock64 ]
then
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the platform-rock64 folder
    # that will refresh the platform files, see below
else
	echo "Get rock64 files from repo"
	git clone --depth 1 https://github.com/volumio/platform-rock64.git platform-rock64
	echo "Unpack the platform files"
    cd platform-rock64
	tar xfJ rock64.tar.xz
	cd ..
fi

echo "Copying the bootloader"
sudo dd if=platform-rock64/rock64/u-boot/idbloader.img of=${LOOP_DEV} seek=64 conv=notrunc
sudo dd if=platform-rock64/rock64/u-boot/uboot.img of=${LOOP_DEV} seek=16384 conv=notrunc
sudo dd if=platform-rock64/rock64/u-boot/trust.img of=${LOOP_DEV} seek=24576 conv=notrunc
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

echo "Copying rock64 boot files"
mkdir /mnt/volumio/rootfs/boot/dtb
mkdir /mnt/volumio/rootfs/boot/extlinux
sudo cp platform-rock64/rock64/boot/Image /mnt/volumio/rootfs/boot
sudo cp platform-rock64/rock64/boot/dtb/*.dtb /mnt/volumio/rootfs/boot/
sudo cp platform-rock64/rock64/boot/config* /mnt/volumio/rootfs/boot

echo "Copying rock64 modules and firmware"
sudo cp -pdR platform-rock64/rock64/lib/modules /mnt/volumio/rootfs/lib/
sudo cp -pdR platform-rock64/rock64/lib/firmware /mnt/volumio/rootfs/lib/

echo "Adding missing alsa dependencies and dt-overlay tool"
sudo cp -pdR platform-rock64/rock64/usr /mnt/volumio/rootfs/

echo "Adding temporary fixes to Rock64 board"
sudo cp -pdR platform-rock64/rock64/etc /mnt/volumio/rootfs/
sync

echo "Preparing to run chroot for more rock64 configuration"
cp scripts/rock64config.sh /mnt/volumio/rootfs
cp scripts/initramfs/init.nextarm /mnt/volumio/rootfs/root/init
cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin
#copy the scripts for updating from usb
wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs
echo $PATCH > /mnt/volumio/rootfs/patch

echo "UUID_DATA=$(blkid -s UUID -o value ${DATA_PART})
UUID_IMG=$(blkid -s UUID -o value ${SYS_PART})
UUID_BOOT=$(blkid -s UUID -o value ${BOOT_PART})
" > /mnt/volumio/rootfs/root/init.sh
chmod +x /mnt/volumio/rootfs/root/init.sh

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
/rock64config.sh
EOF

UIVARIANT_FILE=/mnt/volumio/rootfs/UIVARIANT
if [ -f "${UIVARIANT_FILE}" ]; then
    echo "Starting variant.js"
    node variant.js
    rm $UIVARIANT_FILE
fi

#cleanup
rm /mnt/volumio/rootfs/root/init.sh /mnt/volumio/rootfs/rock64config.sh /mnt/volumio/rootfs/root/init

echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys

echo "==> rock64 device installed"

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
sudo umount -l /mnt/volumio/images
sudo umount -l /mnt/volumio/rootfs/boot

sudo dmsetup remove_all
sudo losetup -d ${LOOP_DEV}
sync

md5sum "$IMG_FILE" > "${IMG_FILE}.md5"
