#!/bin/sh

while getopts ":v:" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
  esac
done
BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-OdroidC.img"

 
if [ -f ${IMG_FILE} ]
then
	echo "Image file: ${IMG_FILE} exists, re-using"
else
	echo "Creating Image File"
	echo "Image file: ${IMG_FILE}"
	dd if=/dev/zero of=${IMG_FILE} bs=1M count=4000
fi

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 1 64
sudo parted -s "${LOOP_DEV}" mkpart primary ext4 65 2113
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -s -a "${LOOP_DEV}"

BOOT_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
SYS_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
echo "Using: " ${BOOT_PART}
echo "Using: " ${SYS_PART}
if [ ! -b "${BOOT_PART}" ]
then
	echo "${BOOT_PART} doesn't exist"
	exit 1
fi

if [ ! -b "${SYS_PART}" ]
then
	echo "${SYS_PART} doesn't exist"
	exit 1
fi

echo "Creating boot and rootfs filesystems"
sudo mkfs -t vfat -n BOOT "${BOOT_PART}"
sudo mkfs -F -t ext4 -L volumio "${SYS_PART}"
sync

echo "Preparing for the Odroid kernel/ platform files"
if [ -d platforms/odroidc ]
then 
	echo "Folder already exists - keeping it"
else
	echo "Creating temporary folder and clone Odroid files from repo"
	sudo mkdir -p platforms/odroidc
	git clone https://github.com/gkkpch/Kernel-OdroidC1.git platforms/odroidc
fi

echo "Copying the bootloader"
sudo dd if=platforms/odroidc/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=1 count=442
sudo dd if=platforms/odroidc/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=512 skip=1 seek=1
sudo dd if=platforms/odroidc/uboot/u-boot.bin of=${LOOP_DEV} seek=64
sync

# change the UUID from boot and rootfs partion
#tune2fs ${BOOT_PART} -U CF56-1F80
#tune2fs ${SYS_PART} -U f87b8078-de6f-431d-b737-f122b015621c
# switch off journaling on ext4 (prevents excessiv wear on the card)
tune2fs -O ^has_journal ${SYS_PART}


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

echo "Copying Volumio RootFs"
echo "Creating mount point for the images partition"
mkdir /mnt/volumio/images
sudo mount -t ext4 "${SYS_PART}" /mnt/volumio/images
sudo mkdir /mnt/volumio/rootfs
sudo cp -pdR build/arm/root/* /mnt/volumio/rootfs
sudo mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot

echo "Copying OdroidC boot files"
sudo cp platforms/odroidc/boot/boot.ini /mnt/volumio/rootfs/boot
sudo cp platforms/odroidc/boot/meson8b_odroidc.dtb /mnt/volumio/rootfs/boot
sudo cp platforms/odroidc/boot/uImage /mnt/volumio/rootfs/boot
#sudo cp platforms/odroidc/boot/uInitrd /mnt/volumio/rootfs/boot

echo "Copying OdroidC modules and firmware"
sudo cp -pdR platforms/odroidc/lib/modules /mnt/volumio/rootfs/lib/
sudo cp -pdR platforms/odroidc/lib/firmware /mnt/volumio/rootfs/lib/

echo "Copying OdroidC inittab"
sudo cp platforms/odroidc/etc/inittab /mnt/volumio/rootfs/etc/

echo "We don't deal in pies, so show neutral :)"
sed -i "s/Raspbian/Debian/g" /mnt/volumio/rootfs/etc/issue

echo "Adding Hardkernel (Odroidc) defaults to initramfs-tools"
sudo cp -pdR platforms/odroidc/usr/share/initramfs-tools /mnt/volumio/rootfs/usr/share

sync

echo "Preparing to run chroot for more OdroidC configuration"
cp scripts/odroidcconfig.sh /mnt/volumio/rootfs
cp scripts/initramfs/init /mnt/volumio/rootfs/root
cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin

#copy the scripts for updating from usb
wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater 

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs

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
sudo cp platforms/odroidc/etc/lirc/lircd.conf /mnt/volumio/rootfs/etc/lirc
sudo cp platforms/odroidc/etc/lirc/lircd.conf /mnt/volumio/rootfs/etc/lirc
sudo cp platforms/odroidc/etc/lirc/lircd.conf /mnt/volumio/rootfs/etc/lirc

echo "==> Odroid-C device installed"  
ls -al /mnt/volumio/rootfs

#echo "Removing temporary platform files"
#echo "(you can keep it safely as long as you're sure of no changes)"
#sudo rm -r platforms/odroidc
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
