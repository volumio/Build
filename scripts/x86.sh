#!/bin/sh


while getopts ":v:" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
  esac
done
BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}x86.img"

echo "Creating Image Bed"
echo "Image file: ${IMG_FILE}"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=2000
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 1 512
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 512 1300
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 1300 100%
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -s -a "${LOOP_DEV}"
 
BOOT_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
IMG_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
DATA_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p3`

if [ ! -b "$BOOT_PART" ]
then
	echo "$BOOT_PART doesn't exist"
	exit 1
fi

echo "Creating filesystems"
sudo mkfs -t vfat -n BOOT "${BOOT_PART}"
sudo mkfs.ext4 -E stride=2,stripe-width=1024 -b 4096 "${IMG_PART}" -L volumio
sudo mkfs.ext4 -E stride=2,stripe-width=1024 -b 4096 "${DATA_PART}" -L volumio_data
sync

echo "Copying Volumio RootFs"
if [ -d /mnt ]
then 
    echo "/mnt folder exist"
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
sudo mount -t ext4 "${IMG_PART}" /mnt/volumio/images
sudo mkdir /mnt/volumio/rootfs
echo "Copying Volumio RootFs"
sudo cp -pdR build/x86/root/* /mnt/volumio/rootfs

sync

echo "Entering Chroot Environment"
sudo mkdir /mnt/volumio/boot
sudo mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot

cp scripts/x86config.sh /mnt/volumio/rootfs
if [ ! -d platform-x86 ]; then
  echo "Platform files (packages) not available yet, getting them from the repo"
  git clone http://github.com/volumio/platform-x86 
fi
cp platform-x86/packages/linux-image-*.deb /mnt/volumio/rootfs
cp platform-x86/packages/linux-firmware-*.deb /mnt/volumio/rootfs
cp volumio/splash/volumio.png /mnt/volumio/rootfs/boot

cp scripts/initramfs/init-x86 /mnt/volumio/rootfs/root/init
cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin

#copy the scripts for updating from usb
wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs

UUID_BOOT=$(blkid ${BOOT_PART} | awk -F'["]' '{print $6}')
UUID_IMG=$(blkid ${IMG_PART} | awk -F'["]' '{print $4}')
echo "UUID_BOOT=${UUID_BOOT}
UUID_IMG=${UUID_IMG}
LOOP_DEV=${LOOP_DEV}
" >> /mnt/volumio/rootfs/init.sh
chmod +x /mnt/volumio/rootfs/init.sh

chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
/x86config.sh
EOF
rm /mnt/volumio/rootfs/init.sh /mnt/volumio/rootfs/linux-image-*.deb /mnt/volumio/rootfs/linux-firmware-*.deb
rm /mnt/volumio/rootfs/root/init /mnt/volumio/rootfs/x86config.sh  
sync

echo "Unmounting Temp Devices"
sudo umount -l /mnt/volumio/rootfs/dev 
sudo umount -l /mnt/volumio/rootfs/proc 
sudo umount -l /mnt/volumio/rootfs/sys 

echo "X86 device installed"  
ls -al /mnt/volumio/rootfs

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
echo "X86 Image file created"
#echo "Building VMDK Virtual Image File"
#qemu-img convert ${IMG_FILE} -O vmdk Volumio.dev.vmdk
#echo "VMDK Virtual Imake File generated"
