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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-OdroidXU4.img"

 
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
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 3072s 266239s
sudo parted -s "${LOOP_DEV}" mkpart primary ext4 266240s 100%
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

echo "Creating filesystems"
sudo mkfs -t vfat -n BOOT "${BOOT_PART}"
sudo mkfs -F -t ext4 -L volumio "${SYS_PART}"
sync

echo "Get the Odroid kernel/ platform files from repo"
if [ -d platforms-O ]
then 
  echo "Folder already exists - keeping it"
else
  echo "Creating temporary folder and clone Odroid files from repo"
  mkdir platforms-O
  git clone https://github.com/gkkpch/Platform-Odroid.git platforms-O
  echo "Don't forget CONFIG_FHANDLE=y in the kernel!!"
fi

echo "Copying the bootloader and trustzone software"
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidxu4/uboot/bl1.bin.hardkernel of=${LOOP_DEV} seek=1
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidxu4/uboot/bl2.bin.hardkernel of=${LOOP_DEV} seek=31
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidxu4/uboot/u-boot.bin.hardkernel of=${LOOP_DEV} seek=63
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidxu4/uboot/tzsw.bin.hardkernel of=${LOOP_DEV} seek=719
echo "Erasing u-boot env"
sudo dd iflag=dsync oflag=dsync if=/dev/zero of=${LOOP_DEV} seek=1231 count=32 bs=512


sync

# change the UUID from boot and rootfs partion
#tune2fs ${BOOT_PART} -U CF56-1F80
#tune2fs ${SYS_PART} -U f87b8078-de6f-431d-b737-f122b015621c
# switch off journaling on ext4 (prevents excessiv wear on the card)
tune2fs -O ^has_journal ${SYS_PART}


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
sudo mount -t ext4 "${SYS_PART}" /mnt/volumio
sudo mkdir /mnt/volumio/boot
sudo mount -t vfat "${BOOT_PART}" /mnt/volumio/boot
sudo cp -pdR build/arm/root/* /mnt/volumio

echo "Copying boot files"
sudo cp platforms-O/odroidxu4/boot/boot.ini /mnt/volumio/boot
sudo cp platforms-O/odroidxu4/boot/zImage /mnt/volumio/boot
sudo cp platforms-O/odroidxu4/boot/uInitrd /mnt/volumio/boot

echo "Copying modules and firmware"
sudo cp -pdR platforms-O/odroidxu4/lib/modules /mnt/volumio/lib/
sudo cp -pdR platforms-O/odroidxu4/lib/firmware /mnt/volumio/lib/

echo "Preparing to run chroot for more OdroidXU configuration"
cp scripts/odroidxu4config.sh /mnt/volumio
mkdir /mnt/volumio/opt/fan-control
cp platforms-O/odroidxu4/opt/fan-control/odroid-xu3-fan-control.sh /mnt/volumio/opt/fan-control
cp platforms-O/odroidxu4/opt/fan-control/odroid-xu3-fan-control.service /mnt/volumio/opt/fan-control
mount /dev /mnt/volumio/dev -o bind
mount /proc /mnt/volumio/proc -t proc
mount /sys /mnt/volumio/sys -t sysfs
echo $PATCH > /mnt/volumio/rootfs/patch
chroot /mnt/volumio /bin/bash -x <<'EOF'
su -
/odroidxu4config.sh
EOF

#cleanup
rm /mnt/volumio/odroidxu4config.sh
echo "Unmounting Temp devices"
umount -l /mnt/volumio/dev 
umount -l /mnt/volumio/proc 
umount -l /mnt/volumio/sys 

#TODO echo "Copying inittab"
#TODO sudo cp platforms-O/odroidxu4/etc/inittab /mnt/volumio/etc/
echo "Copying modified securetty (oDroid-XU4 console)"
sudo cp platforms-O/odroidxu4/etc/securetty /mnt/volumio/etc/

echo "Adding fan control service"

echo "This is not a raspberry, so showing neutral :)"
sed -i "s/Raspbian/Debian/g" /mnt/volumio/etc/issue

sync
echo "Odroid-XU4 device installed" 
  
ls -al /mnt/volumio/

echo "Unmounting Temp Devices"
sudo umount -l /mnt/volumio/boot
sudo umount -l /mnt/volumio/
sudo dmsetup remove_all
sudo losetup -d ${LOOP_DEV}
sync
