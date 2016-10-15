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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-odroidc2.img"


echo "Creating Image File"
echo "Image file: ${IMG_FILE}"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=1600

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 1 64
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 65 1500
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 1500 100%
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

echo "Preparing for the Odroid C2 kernel/ platform files"
if [ -d platforms-O ]
then 
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the platforms-O folder
    # that will refresh all the odroid platforms, see below
	cd platforms-O
	if [ ! -d odroidc2 ]; then
	   tar xfJ odroidc2.tar.xz 
	fi
	cd ..
else
	echo "Clone all Odroid files from repo"
	git clone https://github.com/volumio/Platform-Odroid.git platforms-O
	echo "Unpack the C2 platform files"
    cd platforms-O
	tar xfJ odroidc2.tar.xz
	cd ..
fi

echo "Copying the bootloader"
sudo dd if=platforms-O/odroidc2/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=1 count=442
sudo dd if=platforms-O/odroidc2/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=512 skip=1 seek=1
sudo dd if=platforms-O/odroidc2/uboot/u-boot.bin of=${LOOP_DEV} conv=fsync bs=512 seek=97
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
sudo cp -pdR build/arm/root/* /mnt/volumio/rootfs
echo "Copying OdroidC2 boot files"
sudo cp platforms-O/odroidc2/boot/boot.ini /mnt/volumio/rootfs/boot
sudo cp platforms-O/odroidc2/boot/meson64_odroidc2.dtb /mnt/volumio/rootfs/boot
sudo cp platforms-O/odroidc2/boot/Image /mnt/volumio/rootfs/boot
echo "Copying OdroidC2 modules and firmware"
sudo cp -pdR platforms-O/odroidc2/lib/modules /mnt/volumio/rootfs/lib/
sudo cp -pdR platforms-O/odroidc2/lib/firmware /mnt/volumio/rootfs/lib/
echo "Copying OdroidC2 DAC detection service"
sudo cp platforms-O/odroidc2/etc/odroiddac.service /mnt/volumio/rootfs/lib/systemd/system/
sudo cp platforms-O/odroidc2/etc/odroiddac.sh /mnt/volumio/rootfs/opt/

echo "Copying OdroidC2 inittab"
sudo cp platforms-O/odroidc2/etc/inittab /mnt/volumio/rootfs/etc/

#TODO: odroids should be able to run generic debian
sed -i "s/Raspbian/Debian/g" /mnt/volumio/rootfs/etc/issue

sync

echo "Preparing to run chroot for more Odroid-${MODEL} configuration"
cp scripts/odroidc2config.sh /mnt/volumio/rootfs
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
/odroidc2config.sh
EOF

#cleanup
rm /mnt/volumio/rootfs/odroidc2config.sh /mnt/volumio/rootfs/root/init

echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev 
umount -l /mnt/volumio/rootfs/proc 
umount -l /mnt/volumio/rootfs/sys 

echo "Copying LIRC configuration files for HK stock remote"
sudo cp platforms-O/odroidc2/etc/lirc/lircd.conf /mnt/volumio/rootfs/etc/lirc
sudo cp platforms-O/odroidc2/etc/lirc/hardware.conf /mnt/volumio/rootfs/etc/lirc
sudo cp platforms-O/odroidc2/etc/lirc/lircrc /mnt/volumio/rootfs/etc/lirc

echo "==> Odroid-C2 device installed"  

#echo "Removing temporary platform files"
#echo "(you can keep it safely as long as you're sure of no changes)"
#sudo rm -r platforms-O
sync

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
