#!/bin/sh

while getopts ":v:" opt; do
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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-odroidx2.img"

echo "Creating Image File"
echo "Image file: ${IMG_FILE}"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=2000

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 3072s 266239s
sudo parted -s "${LOOP_DEV}" mkpart primary ext4 266240s 2929687s
sudo parted -s "${LOOP_DEV}" mkpart primary ext4 2929688s 100%
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

echo "Creating filesystems"
sudo mkfs -t vfat -n BOOT "${BOOT_PART}"
sudo mkfs -F -t ext4 -L volumio "${SYS_PART}"
sudo mkfs -F -t ext4 -L volumio_data "${DATA_PART}"
sync

echo "Get the Odroid kernel/ platform files from repo"
if [ -d platforms-O ]
then 
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the platforms-O folder
    # that will refresh all the odroid platforms, see below
	cd platforms-O
	if [ ! -d odroidx2 ]; then
	   tar xfJ odroidx2.tar.xz 
	fi
	cd ..
else
	echo "Clone all Odroid files from repo"
	git clone https://github.com/gkkpch/Platform-Odroid.git platforms-O
	echo "Unpack the X2 platform files"
    cd platforms-O
    tar xfJ odroidx2.tar.xz 
    cd ..
fi

echo "Copying the bootloader and trustzone software"
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidx2/uboot/E4412_S.bl1.HardKernel.bin of=${LOOP_DEV} seek=1
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidx2/uboot/bl2.signed.bin of=${LOOP_DEV} seek=31
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidx2/uboot/u-boot.bin of=${LOOP_DEV} seek=63
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidx2/uboot/E4412_S.tzsw.signed.bin of=${LOOP_DEV} seek=2111

echo "Erasing and writing u-boot environment" 
sudo dd if=/dev/zero of=${LOOP_DEV} bs=1 seek=1310720 count=4096
sudo echo "${LOOP_DEV}		0x140000		0x1000" > /etc/fw_env.config
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

echo "Copying rootfs"
mkdir /mnt/volumio/images
sudo mount -t ext4 "${SYS_PART}" /mnt/volumio/images
sudo mkdir /mnt/volumio/rootfs
sudo cp -pdR build/arm/root/* /mnt/volumio/rootfs
sudo mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot

echo "Copying boot files"
mkimage -A arm -T script -C none -n "Boot script for ODROID-X2" -d platforms-O/odroidx2/boot/boot.cmd /mnt/volumio/rootfs/boot/boot.scr
#
#
#TODO Don't forget CONFIG_FHANDLE=y in the kernel!!
#
#
sudo cp platforms-O/odroidx2/boot/zImage /mnt/volumio/rootfs/boot
sudo cp platforms-O/odroidx2/boot/exynos4412-odroidx2.dtb /mnt/volumio/rootfs/boot

echo "Copying modules and firmware"
sudo cp -pdR platforms-O/odroidx2/lib/modules /mnt/volumio/rootfs/lib/
sudo cp -pdR platforms-O/odroidx2/lib/firmware /mnt/volumio/rootfs/lib/

echo "Copying inittab"
sudo cp platforms-O/odroidx2/etc/inittab /mnt/volumio/rootfs/etc/
echo "Copying modified securetty (oDroid-X2 console)"
sudo cp platforms-O/odroidx2/etc/securetty /mnt/volumio/rootfs/etc/

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

echo "Cleaning build environment"
rm -rf /mnt/volumio /mnt/boot

sudo dmsetup remove_all
sudo losetup -d ${LOOP_DEV}
sync
