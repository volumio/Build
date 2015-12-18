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
dd if=/dev/zero of=${IMG_FILE} bs=1M count=2048
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 1 2048
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -s -a "${LOOP_DEV}"
 
LOOP_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p1`

if [ ! -b "$LOOP_PART" ]
then
	echo "$LOOP_PART doesn't exist"
	exit 1
fi

echo "Creating filesystems"
sudo mkfs.ext4 -E stride=2,stripe-width=1024 -b 4096 "${LOOP_PART}" -L volumio
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
sudo mount -t ext4 "${LOOP_PART}" /mnt/volumio
sudo rm -rf /mnt/volumio/*
sudo cp -pdR build/x86/root/* /mnt/volumio
sync

echo "Entering Chroot Environment"

cp scripts/x86config.sh /mnt/volumio

mount /dev /mnt/volumio/dev -o bind
mount /proc /mnt/volumio/proc -t proc
mount /sys /mnt/volumio/sys -t sysfs

UUID=$(blkid ${LOOP_PART} | awk -F'["]' '{print $4}')
echo "UUID=${UUID}
LOOP_PART=${LOOP_PART}
LOOP_DEV=${LOOP_DEV}
" >> /mnt/volumio/init.sh
chmod +x /mnt/volumio/init.sh

chroot /mnt/volumio /bin/bash -x <<'EOF'
/x86config.sh
EOF
rm /mnt/volumio/x86config.sh /mnt/volumio/init.sh
sync

ls -al /mnt/volumio/
echo "Unmounting Temp Devices"
sudo umount -l /mnt/volumio/
dmsetup remove_all
sudo losetup -d ${LOOP_DEV}

echo "X86 Image file created"
echo "Building VMDK Virtual Image File"
qemu-img convert ${IMG_FILE} -O vmdk Volumio.dev.vmdk
echo "VMDK Virtual Imake File generated"
