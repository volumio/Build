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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-sopine64.img"

if [ "$ARCH" = arm ]; then
  DISTRO="Raspbian"
else
  DISTRO="Debian 32bit"
fi

echo "Creating Image File ${IMG_FILE} with ${DISTRO} rootfs"

dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800

echo "Creating Image Bed"
LOOP_DEV=`losetup -f --show ${IMG_FILE}`
# Note: leave the first 20Mb free for the firmware
parted -s "${LOOP_DEV}" mklabel msdos
parted -s "${LOOP_DEV}" mkpart primary fat32 21 84
parted -s "${LOOP_DEV}" mkpart primary ext3 84 2500
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
mkfs -F -t ext4 -O ^metadata_csum,^64bit -L volumio "${SYS_PART}" || mkfs -F -t ext4 -L volumio "${SYS_PART}"
mkfs -F -t ext4 -O ^metadata_csum,^64bit -L volumio_data "${DATA_PART}" || mkfs -F -t ext4 -L volumio_data "${DATA_PART}"
sync

echo "Preparing for the (so)Pine64(LTS) kernel/ platform files"
if [ -d platform-pine64 ]
then
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the platform-pine64 folder
    # that will refresh all the odroid platforms, see below
    cd platform-pine64
	if [ -f sopine64lts.tar.xz ]; then
	   echo "Found a new tarball, unpacking..."
	   [ -d sopine64lts ] || rm -r sopine64lts
	   tar xfJ sopine64lts.tar.xz
	   rm sopine64lts.tar.xz
	fi
	cd ..
else
	echo "Clone (so)Pine64(LTS) files from repo"
	wget https://github.com/volumio/platform-pine64/raw/master/sopine64lts.tar.xz
	echo "Unpacking the platform files"echo "Unpack the (so)Pine64(LTS) platform files"
    cd platform-pine64
	tar xfJ sopine64lts.tar.xz
	cd ..
fi

#mainline u-boot
dd if=platform-pine64/sopine64lts/u-boot/sunxi-spl.bin of=${LOOP_DEV} conv=fsync bs=8k seek=1
dd if=platform-pine64/sopine64lts/u-boot/u-boot.itb of=${LOOP_DEV} conv=fsync bs=8k seek=5
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

echo "Copying (so)Pine64(LTS) boot files"
mkdir /mnt/volumio/rootfs/boot/dtb
cp platform-pine64/sopine64lts/boot/Image /mnt/volumio/rootfs/boot
cp -R platform-pine64/sopine64lts/boot/dtb/* /mnt/volumio/rootfs/boot/dtb
cp platform-pine64/sopine64lts/boot/uEnv.txt.sopine64lts /mnt/volumio/rootfs/boot/uEnv.txt
cp platform-pine64/sopine64lts/boot/boot.cmd /mnt/volumio/rootfs/boot

echo "Compiling boot script"
mkimage -C none -A arm -T script -d platform-pine64/sopine64lts/boot/boot.cmd /mnt/volumio/rootfs/boot/boot.scr

echo "Copying kernel configuration file"
cp platform-pine64/sopine64lts/boot/config* /mnt/volumio/rootfs/boot

echo "Copying (so)Pine64(LTS) kernel modules"
cp -pdR platform-pine64/sopine64lts/lib/modules /mnt/volumio/rootfs/lib/

echo "Confguring ALSA with sane defaults"
cp platform-pine64/sopine64lts/var/lib/alsa/* /mnt/volumio/rootfs/var/lib/alsa

echo "Copying firmware"
cp -R platform-pine64/sopine64lts/firmware/* /mnt/volumio/rootfs/lib/firmware
sync

echo "Preparing to run chroot for more so(PINE64)lts configuration)"
cp scripts/sopine64ltsconfig.sh /mnt/volumio/rootfs
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
/sopine64ltsconfig.sh
EOF

UIVARIANT_FILE=/mnt/volumio/rootfs/UIVARIANT
if [ -f "${UIVARIANT_FILE}" ]; then
    echo "Starting variant.js"
    node variant.js
    rm $UIVARIANT_FILE
fi

#cleanup
rm /mnt/volumio/rootfs/root/init.sh /mnt/volumio/rootfs/sopine64ltsconfig.sh /mnt/volumio/rootfs/root/init

echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys

#echo "Copying LIRC configuration files"
#cp platform-pine64/pine64/etc/lirc/lircd.conf /mnt/volumio/rootfs/etc/lirc
#cp platform-pine64/pine64/etc/lirc/hardware.conf /mnt/volumio/rootfs/etc/lirc
#cp platform-pine64/pine64/etc/lirc/lircrc /mnt/volumio/rootfs/etc/lirc

echo "==> soPine64/ Pine64 LTS device installed"
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
