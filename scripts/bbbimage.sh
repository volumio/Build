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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-bbb.img"


echo "Creating Image File"
echo "Image file: ${IMG_FILE}"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=1900

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`

sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 1 64
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 65 1700
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 1700 100%
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

echo "Preparing for the BeagleBone Black kernel/ platform files"
if [ -d platform-bbb ]
then
	echo "Platform folder already exists - keeping it"
    # if you really want to re-clone from the repo, then delete the platforms-bbb folder
    #Take a look at platform-odroid repo to see what we need here.
else
	echo "Clone all cubox files from repo"
  #ideally in the end we'll have a tar here
	git clone https://github.com/volumio/platform-bbb.git platform-bbb
	echo "Unpack the cubox platform files"
    cd platform-bbb
    #if you don't want to untar every time, just move files over
	tar xfJ bbb.tar.xz
	cd ..
fi

#TODO: Check!!!!
echo "Copying the bootloader"
echo "Burning bootloader"
sudo dd if=platform-bbb/bbb/uboot/SPL of=${LOOP_DEV} bs=1K seek=1
sudo dd if=platform-bbb/bbb/uboot/u-boot.img of=${LOOP_DEV} bs=1K seek=42
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

echo "Copying bbb boot files, Kernel, Modules and Firmware"
#I've kept those for reference, probably you don't need aliases or confs
sudo cp platform-bbb/bbb/boot/* /mnt/volumio/rootfs/boot
sudo cp -pdR platform-bbb/bbb/lib/modules /mnt/volumio/rootfs/lib
sudo cp -pdR platform-bbb/bbb/lib/firmware /mnt/volumio/rootfs/lib
sudo cp -pdR platform-bbb/bbb/usr/share/alsa/cards/imx-hdmi-soc.conf /mnt/volumio/rootfs/usr/share/alsa/cards
sudo cp -pdR platform-bbb/bbb/usr/share/alsa/cards/imx-spdif.conf /mnt/volumio/rootfs/usr/share/alsa/cards
sudo cp -pdR platform-bbb/bbb/usr/share/alsa/cards/aliases.conf /mnt/volumio/rootfs/usr/share/alsa/cards
sudo chown root:root /mnt/volumio/rootfs/usr/share/alsa/cards/imx-hdmi-soc.conf
sudo chown root:root /mnt/volumio/rootfs/usr/share/alsa/cards/imx-spdif.conf
sudo chown root:root /mnt/volumio/rootfs/usr/share/alsa/cards/aliases.conf

sync

echo "Preparing to run chroot for more bbb configuration"
cp scripts/bbbconfig.sh /mnt/volumio/rootfs
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
/bbbconfig.sh
EOF

#cleanup
rm /mnt/volumio/rootfs/bbbconfig.sh /mnt/volumio/rootfs/root/init

echo "Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys

echo "==> bbb device installed"

#echo "Removing temporary platform files"
#echo "(you can keep it safely as long as you're sure of no changes)"
#sudo rm -r platforms-bbb
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
