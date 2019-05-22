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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-odroidx2.img"

if [ "$ARCH" = arm ]; then
  DISTRO="Raspbian"
else
  DISTRO="Debian 32bit"
fi

echo "Creating Image File ${IMG_FILE} with $DISTRO rootfs"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800

echo "Creating Image Bed"
LOOP_DEV=`losetup -f --show ${IMG_FILE}`

parted -s "${LOOP_DEV}" mklabel msdos
parted -s "${LOOP_DEV}" mkpart primary fat32 3072s 64
parted -s "${LOOP_DEV}" mkpart primary ext4 64 2500
parted -s "${LOOP_DEV}" mkpart primary ext4 2500 100%
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

echo "Creating filesystems"
mkfs -t vfat -n BOOT "${BOOT_PART}"
mkfs -F -t ext4 -L volumio "${SYS_PART}"
mkfs -F -t ext4 -L volumio_data "${DATA_PART}"
sync

echo "Get the Odroid kernel/ platform files from repo"
if [ -d platform-odroid ]
then
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the platform-odroid folder
    # that will refresh all the odroid platforms, see below
	cd platform-odroid
	if [ ! -d odroidx2 ]; then
	   tar xfJ odroidx2.tar.xz
	fi
	cd ..
else
	echo "Clone all Odroid files from repo"
	git clone --depth 1 https://github.com/gkkpch/Platform-Odroid.git platform-odroid
	echo "Unpack the X2 platform files"
    cd platform-odroid
    tar xfJ odroidx2.tar.xz
    cd ..
fi

echo "Copying the bootloader and trustzone software"
dd iflag=dsync oflag=dsync if=platform-odroid/odroidx2/uboot/E4412_S.bl1.HardKernel.bin of=${LOOP_DEV} seek=1
dd iflag=dsync oflag=dsync if=platform-odroid/odroidx2/uboot/bl2.signed.bin of=${LOOP_DEV} seek=31
dd iflag=dsync oflag=dsync if=platform-odroid/odroidx2/uboot/u-boot.bin of=${LOOP_DEV} seek=63
dd iflag=dsync oflag=dsync if=platform-odroid/odroidx2/uboot/E4412_S.tzsw.signed.bin of=${LOOP_DEV} seek=2111

echo "Erasing and writing u-boot environment"
dd if=/dev/zero of=${LOOP_DEV} bs=1 seek=1310720 count=4096
echo "${LOOP_DEV}		0x140000		0x1000" > /etc/fw_env.config
fw_setenv bootcmd 'run loadscript'
fw_setenv bootdelay '2'
fw_setenv fdtfile 'exynos4412-odroidx2.dtb'
fw_setenv loadscript 'fatload mmc 0:1 ${scriptaddr} boot.scr; source ${scriptaddr}'
fw_setenv scriptaddr '0x40408000'
echo "u-boot env:"
fw_printenv
sync

echo "Copying Volumio RootFs"
if [ -d /mnt ]
then
  echo "/mnt/folder exist"
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

echo "Copying rootfs"
mkdir /mnt/volumio/images
mount -t ext4 "${SYS_PART}" /mnt/volumio/images
mkdir /mnt/volumio/rootfs
cp -pdR build/$ARCH/root/* /mnt/volumio/rootfs
mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot

echo "Copying boot files"
mkimage -A arm -T script -C none -n "Boot script for ODROID-X2" -d platform-odroid/odroidx2/boot/boot.cmd /mnt/volumio/rootfs/boot/boot.scr
#
#
#TODO Don't forget CONFIG_FHANDLE=y in the kernel!!
#
#
cp platform-odroid/odroidx2/boot/zImage /mnt/volumio/rootfs/boot
cp platform-odroid/odroidx2/boot/exynos4412-odroidx2.dtb /mnt/volumio/rootfs/boot

echo "Copying modules and firmware"
cp -pdR platform-odroid/odroidx2/lib/modules /mnt/volumio/rootfs/lib/
cp -pdR platform-odroid/odroidx2/lib/firmware /mnt/volumio/rootfs/lib/

echo "Copying inittab"
cp platform-odroid/odroidx2/etc/inittab /mnt/volumio/rootfs/etc/
echo "Copying modified securetty (oDroid-X2 console)"
cp platform-odroid/odroidx2/etc/securetty /mnt/volumio/rootfs/etc/

echo "Preparing to run chroot for more Odroid-X2 configuration"
cp scripts/odroidx2config.sh /mnt/volumio/rootfs
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
/odroidx2config.sh
EOF

#cleanup
rm /mnt/volumio/rootfs/odroidx2config.sh /mnt/volumio/rootfs/root/init

echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys

sync
echo "Odroid-XU4 device installed"

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
