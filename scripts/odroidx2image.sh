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
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-OdroidX2.img"

 
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
if [ -d platforms-O]
then 
  echo "Platform-O folder already exists - keeping it"
else
  echo "remember CONFIG_FHANDLE=y Option sneeds to be set"
  mkdir platforms-O
  git clone https://github.com/gkkpch/Platform-Odroid.git platforms-O
fi

echo "Copying the bootloader and trustzone software"
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidx2/uboot/E4412_S.bl1.HardKernel.bin of=${LOOP_DEV} seek=1
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidx2/uboot/bl2.signed.bin of=${LOOP_DEV} seek=31
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidx2/uboot/u-boot.bin of=${LOOP_DEV} seek=63
sudo dd iflag=dsync oflag=dsync if=platforms-O/odroidx2/uboot/E4412_S.tzsw.signed.bin of=${LOOP_DEV} seek=2111
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
sudo cp platforms-O/odroidx2/boot/boot.scr /mnt/volumio/boot

#
#
# Don't forget CONFIG_FHANDLE=y in the kernel!!
#
#
sudo cp platforms-O/odroidx2/boot/zImage /mnt/volumio/boot
sudo cp platforms-O/odroidx2/boot/uInitrd /mnt/volumio/boot

echo "Copying modules and firmware"
sudo cp -pdR platforms-O/odroidx2/lib/modules /mnt/volumio/lib/
sudo cp -pdR platforms-O/odroidx2/lib/firmware /mnt/volumio/lib/

echo "Copying inittab"
sudo cp platforms-O/odroidx2/etc/inittab /mnt/volumio/etc/
echo "Copying modified securetty (oDroid-X2 console)"
sudo cp platforms-O/odroidx2/etc/securetty /mnt/volumio/etc/
echo "We don't do raspberries, so showing neutral :)"
sed -i "s/Raspbian/Debian/g" /mnt/volumio/etc/issue
sync

# ***************
# Create fstab
# ***************
echo "Creating fstab"
echo "# Odroid fstab
 
/dev/mmcblk0p2  /        ext4    errors=remount-ro,rw,noatime,nodiratime  0 1
/dev/mmcblk0p1  /boot    vfat    defaults,ro,owner,flush,umask=000        0 0
tmpfs           /var/log tmpfs   defaults,noatime,mode=0755				  0 0
tmpfs			/var/log/volumio tmpfs size=20M,nodev,mode=0777           0 0
tmpfs			/var/log/mpd tmpfs size=20M,nodev,mode=0777           0 0
tmpfs           /tmp     tmpfs   nodev,nosuid,mode=1777                   0 0
" > /mnt/volumio/etc/fstab

echo "Adding volumio-remote-updater"
wget -P /mnt/volumio/usr/local/bin/ http://updates.volumio.org/jx
#wget -P /usr/local/sbin/ http://repo.volumio.org/Volumio2/Binaries/volumio-remote-updater.jx
wget -P /mnt/volumio/usr/local/sbin/ http://updates.volumio.org/volumio-remote-updater.jx
chmod +x /mnt/volumio/usr/local/sbin/volumio-remote-updater.jx /mnt/volumio/usr/local/bin/jx

echo "Odroid-X2 device installed" 
  
ls -al /mnt/volumio/

echo "Unmounting Temp Devices"
sudo umount -l /mnt/volumio/boot
sudo umount -l /mnt/volumio/
sudo dmsetup remove_all
sudo losetup -d ${LOOP_DEV}
sync
