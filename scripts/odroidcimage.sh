#!/bin/bash

#Help function
function HELP {
  echo -e "Basic usage: ./scripts/odroidcimage.sh -v 2.0 -m Cn"\\n
  echo "Switches:"
  echo "-m      --Model, usage: C1 (Odroid C1/C1+), C2 (Odroid C2)"
  echo "-v      --Version, must be a dot separated number. Example 2.102"
  exit 1
}

while getopts v:m: opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
	m)
	  MODEL=$OPTARG
      ;;
  esac
done

#Check the number of arguments. If none are passed, print help and exit.
NUMARGS=$#
if [ $NUMARGS -eq 0 ]; then
  HELP
fi

if [ ! $MODEL == C1 ] && [ ! $MODEL == C2 ]; then
  echo "Wrong Odroid Model number (must be C1 or C2)"
  exit 1
fi 


BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-Odroid${MODEL}.img"


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

echo "Preparing for the Odroid kernel/ platform files"
if [ -d platforms-O ]
then 
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the odroidc folder
    # that will refresh all the odroid platforms, see below
	cd platforms-O
	if [ $MODEL == C1 ]; then	
	   if [ ! -d odroidc1 ]; then
	      tar xvfJ odroidc1.tar.xz 
	   fi
	else
	   if [ ! -d odroidc2 ]; then
	      tar xvfJ odroidc2.tar.xz 
	   fi
	fi
	cd ..
else
	echo "Clone all Odroid files from repo"
	git clone https://github.com/gkkpch/Platform-Odroid.git platforms-O
	echo "Unpack the C1/C1+/C2 platform files"
    cd platforms-O
	if [ $MODEL == C1 ]; then	
    	tar xvfJ odroidc1.tar.xz 
	else
		tar xvfJ odroidc2.tar.xz
	fi
    cd ..
fi

echo "Copying the bootloader"
if [ $MODEL == C1 ]; then
   sudo dd if=platforms-O/odroidc1/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=1 count=442
   sudo dd if=platforms-O/odroidc1/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=512 skip=1 seek=1
   sudo dd if=platforms-O/odroidc1/uboot/u-boot.bin of=${LOOP_DEV} seek=64
else
   sudo dd if=platforms-O/odroidc2/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=1 count=442
   sudo dd if=platforms-O/odroidc2/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=512 skip=1 seek=1
   sudo dd if=platforms-O/odroidc2/uboot/u-boot.bin of=${LOOP_DEV} conv=fsync bs=512 seek=97
fi
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

if [ $MODEL == C1 ]; then
   echo "Copying Volumio RootFs"
   sudo cp -pdR build/arm/root/* /mnt/volumio/rootfs
   echo "Copying OdroidC1 boot files"
   sudo cp platforms-O/odroidc1/boot/boot.ini /mnt/volumio/rootfs/boot
   sudo cp platforms-O/odroidc1/boot/meson8b_odroidc.dtb /mnt/volumio/rootfs/boot
   sudo cp platforms-O/odroidc1/boot/uImage /mnt/volumio/rootfs/boot
   echo "Copying OdroidC1 modules and firmware"
   sudo cp -pdR platforms-O/odroidc1/lib/modules /mnt/volumio/rootfs/lib/
   sudo cp -pdR platforms-O/odroidc1/lib/firmware /mnt/volumio/rootfs/lib/
   echo "Copying OdroidC1 inittab"
   sudo cp platforms-O/odroidc1/etc/inittab /mnt/volumio/rootfs/etc/
else
#TODO: real arm64 rootfs
   echo "Copying Volumio RootFs"
   sudo cp -pdR build/arm/root/* /mnt/volumio/rootfs
   echo "Copying OdroidC2 boot files"
   sudo cp platforms-O/odroidc2/boot/boot.ini /mnt/volumio/rootfs/boot
   sudo cp platforms-O/odroidc2/boot/meson64_odroidc2.dtb /mnt/volumio/rootfs/boot
   sudo cp platforms-O/odroidc2/boot/Image /mnt/volumio/rootfs/boot
   echo "Copying OdroidC2 modules and firmware"
   sudo cp -pdR platforms-O/odroidc2/lib/modules /mnt/volumio/rootfs/lib/
   sudo cp -pdR platforms-O/odroidc2/lib/firmware /mnt/volumio/rootfs/lib/
   echo "Copying OdroidC2 inittab"
   sudo cp platforms-O/odroidc2/etc/inittab /mnt/volumio/rootfs/etc/
fi

#TODO: odroids should be able to run generic debian
sed -i "s/Raspbian/Debian/g" /mnt/volumio/rootfs/etc/issue

sync

echo "Preparing to run chroot for more Odroid-${MODEL} configuration"
cp scripts/odroidcconfig.sh /mnt/volumio/rootfs
cp scripts/initramfs/init /mnt/volumio/rootfs/root
cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin
#copy the scripts for updating from usb
wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs
touch /mnt/volumio/rootfs/${MODEL}.flag

chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/odroidcconfig.sh
EOF

#cleanup
rm /mnt/volumio/rootfs/odroidcconfig.sh /mnt/volumio/rootfs/root/init

echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev 
umount -l /mnt/volumio/rootfs/proc 
umount -l /mnt/volumio/rootfs/sys 

echo "Copying LIRC configuration files for HK stock remote"
if [ $MODEL == C1 ]; then
   sudo cp platforms-O/odroidc1/etc/lirc/lircd.conf /mnt/volumio/rootfs/etc/lirc
   sudo cp platforms-O/odroidc1/etc/lirc/hardware.conf /mnt/volumio/rootfs/etc/lirc
   sudo cp platforms-O/odroidc1/etc/lirc/lircrc /mnt/volumio/rootfs/etc/lirc
else
   sudo cp platforms-O/odroidc2/etc/lirc/lircd.conf /mnt/volumio/rootfs/etc/lirc
   sudo cp platforms-O/odroidc2/etc/lirc/hardware.conf /mnt/volumio/rootfs/etc/lirc
   sudo cp platforms-O/odroidc2/etc/lirc/lircrc /mnt/volumio/rootfs/etc/lirc
fi

echo "==> Odroid-${MODEL} device installed"  

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
