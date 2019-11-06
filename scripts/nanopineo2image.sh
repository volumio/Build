#!/bin/sh

# Build Architecture Debian 32bit
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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-nanopineo2.img"

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
mkfs -F -t ext4 -L volumio "${SYS_PART}"
mkfs -F -t ext4 -L volumio_data "${DATA_PART}"
sync

GETNEO2=yes
echo "Preparing for the nanopi-neo2 kernel/ platform files"
if [ -d platform-nanopi ]; then
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the platform-nanopi/nanopi-neo2 folder
	cd platform-nanopi
	if [ -d nanopi-neo2 ]; then
	  GETNEO2=no
	  if [ -f nanopi-neo2.tar.xz ]; then
	    echo "Found a new tarball, unpacking..."
	   	rm -r nanopi-neo2
	    tar xfJ nanopi-neo2.tar.xz
	    rm nanopi-neo2.tar.xz
      fi
	fi
	cd ..
fi

if [ "$GETNEO2" = "yes" ]; then
	echo "Clone nanopi-neo2 files from repo"
    if [ ! -d platform-nanopi ]; then
	  mkdir platform-nanopi
	fi
    cd platform-nanopi
	wget https://github.com/volumio/platform-nanopi/raw/master/nanopi-neo2.tar.xz
	echo "Unpack the platform files"
	tar xfJ nanopi-neo2.tar.xz
	rm nanopi-neo2.tar.xz
	cd ..
fi

echo "Copying the bootloader"
dd if=platform-nanopi/nanopi-neo2/u-boot/sunxi-spl.bin of=${LOOP_DEV} bs=1024 seek=8
dd if=platform-nanopi/nanopi-neo2/u-boot/u-boot.itb of=${LOOP_DEV} bs=1024 seek=40
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
echo "Copying nanopineo2 boot & kernel config files"
cp platform-nanopi/nanopi-neo2/boot/Image /mnt/volumio/rootfs/boot
cp platform-nanopi/nanopi-neo2/boot/*.dtb /mnt/volumio/rootfs/boot
echo "Setting i2s-generic dtb version as default..."
cp /mnt/volumio/rootfs/boot/sun50i-h5-nanopi-neo2.dtb /mnt/volumio/rootfs/boot/sun50i-h5-nanopi-neo2-org-default.dts
cp platform-nanopi/nanopi-neo2/boot/sun50i-h5-nanopi-neo2-i2s-generic.dtb /mnt/volumio/rootfs/boot/sun50i-h5-nanopi-neo2.dtb
cp platform-nanopi/nanopi-neo2/boot/config* /mnt/volumio/rootfs/boot
cp platform-nanopi/nanopi-neo2/boot/boot.cmd /mnt/volumio/rootfs/boot

echo "Compiling u-boot boot script"
mkimage -C none -A arm -T script -d platform-nanopi/nanopi-neo2/boot/boot.cmd /mnt/volumio/rootfs/boot/boot.scr

echo "Copying nanopineo2 modules"
cp -pdR platform-nanopi/nanopi-neo2/lib/modules /mnt/volumio/rootfs/lib/
cp -pdR platform-nanopi/nanopi-neo2/lib/firmware /mnt/volumio/rootfs/lib/
sync

echo "Preparing to run chroot for more nanopi neo2 configuration"
cp scripts/nanopineo2config.sh /mnt/volumio/rootfs
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
/nanopineo2config.sh
EOF

UIVARIANT_FILE=/mnt/volumio/rootfs/UIVARIANT
if [ -f "${UIVARIANT_FILE}" ]; then
    echo "Starting variant.js"
    node variant.js
    rm $UIVARIANT_FILE
fi


#cleanup
rm /mnt/volumio/rootfs/nanopineo2config.sh /mnt/volumio/rootfs/root/init

echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys

echo "==> nanopineo2 device installed"
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
umount -l /mnt/volumio/images
umount -l /mnt/volumio/rootfs/boot

dmsetup remove_all
losetup -d ${LOOP_DEV}
sync

md5sum "$IMG_FILE" > "${IMG_FILE}.md5"
