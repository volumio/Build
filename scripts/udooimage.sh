#!/bin/sh
usage()
{
cat << EOF
usage: $0 options

OPTIONS:
   -v      Volumio Version
   -d      Platform: UDOO etc
EOF
}

TEST=
SERVER=
PASSWD=
VERBOSE=
while getopts “ht:r:p:v” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             VERSION=$OPTARG
             ;;
         d)
             DEVICE=$OPTARG
             ;;
         ?)
             usage
             exit
             ;;
     esac
done

IMG_FILE="Volumio.img"
 
echo "Creating Image Bed"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=1000
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
 
sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" unit cyl mkpart primary ext3 -- 2cyl -0
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
 
echo "Creating filesystems"
sudo mkfs.ext4 -O ^has_journal -E stride=2,stripe-width=1024 -b 4096 "${LOOP_DEV}" -L volumio
sync
 
echo "Burning bootloader"
sudo dd if=/dev/zero of=${LOOP_DEV} bs=1k count=1023 seek=1
sudo dd if=platforms/udoo/uboot/u-boot-q.imx of=${LOOP_DEV} bs=512 seek=2
sync

 
echo "Copying Volumio RootFs"
sudo mkdir /mnt
sudo mkdir /mnt/volumio
sudo mount -t ext4 "${LOOP_DEV}" /mnt/volumio
sudo rm -rf /mnt/volumio/*
sudo cp -r build/root/* /mnt/volumio
fi
sync

echo "Copying Kernel"
sudo cp -r platforms/udoo/boot /mnt/volumio/boot
 
echo "Copying Modules and Firmwares"
sudo cp -r platforms/udoo/lib/modules /mnt/volumio/lib/modules
sudo cp -r platforms/udoo/firmware /mnt/volumio/lib/firmware
sync
  
ls -al /mnt/volumio/
 
sudo umount /mnt/volumio/
 
echo
echo Umount
echo
sudo losetup -d ${LOOP_DEV}
