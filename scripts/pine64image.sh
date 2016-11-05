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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-pine64.img"


echo "Creating Image File"
echo "Image file: ${IMG_FILE}"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=1600

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
# Note: leave the first 20Mb free for the firmware
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 21 84
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 84 1520
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 1520 100%
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

echo "Preparing for the pine64 kernel/ platform files"
if [ -d platform-pine64 ]
then 
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the platform-pine64 folder
    # that will refresh all the odroid platforms, see below
else
	echo "Clone pine64 files from repo"
	git clone https://github.com/volumio/platform-pine64.git platform-pine64
	echo "Unpack the platform files"
    cd platform-pine64
	tar xfJ pine64.tar.xz
	cd ..
fi

echo "Copying the bootloader"
sudo dd if=platform-pine64/pine64/u-boot/boot0.bin of=${LOOP_DEV} conv=notrunc bs=1k seek=8
sudo dd if=platform-pine64/pine64/u-boot/u-boot-with-dtb.bin of=${LOOP_DEV} conv=notrunc bs=1k seek=19096
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
echo "Copying pine64 boot files"
mkdir /mnt/volumio/rootfs/boot/pine64
sudo cp platform-pine64/pine64/boot/pine64/Image /mnt/volumio/rootfs/boot/pine64
sudo cp platform-pine64/pine64/boot/pine64/*.dtb /mnt/volumio/rootfs/boot/pine64
sudo cp platform-pine64/pine64/boot/uEnv.txt /mnt/volumio/rootfs/boot
sudo cp platform-pine64/pine64/boot/Image.version /mnt/volumio/rootfs/boot
sudo cp platform-pine64/pine64/boot/config* /mnt/volumio/rootfs/boot

echo "Copying pine64 modules and firmware"
sudo cp -pdR platform-pine64/pine64/lib/modules /mnt/volumio/rootfs/lib/
sudo cp -pdR platform-pine64/pine64/lib/firmware /mnt/volumio/rootfs/lib/

echo "Confguring ALSA with sane defaults"
sudo cp platform-pine64/pine64/var/lib/alsa/asound.state /mnt/volumio/rootfs/var/lib/alsa/asound.state

#TODO: pine64 should be able to run generic debian
#sed -i "s/Raspbian/Debian/g" /mnt/volumio/rootfs/etc/issue

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

chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/pine64config.sh
EOF

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

md5sum "$IMG_FILE" > "${IMG_FILE}.md5"
