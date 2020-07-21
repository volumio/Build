#!/bin/bash

SRC="$(pwd)"

while getopts ":d:v:f:" opt; do
  case $opt in
    d)
      DEVICE=$OPTARG
      ;;
    v)
      VERSION=$OPTARG
      ;;
    f)
	  if [ ! -f $OPTARG ]; then
         echo "[err] Volumio image $OPTARG does not exist, aborting..."
         exit 1
      else
         FILENAME=$(basename "$OPTARG" ".zip")
         VOLUMIOIMAGE=$(dirname "$VOLUMIOIMAGE")/$(basename "$OPTARG" ".zip")
         if [ ! -f $VOLUMIOIMAGE ]; then
            unzip $OPTARG
            echo "[err] Volumio image $VOLUMIOIMAGE does not exist, aborting..."
            exit
         fi
      fi
      ;;
  esac
done

if [ "x${DEVICE}" == "x" ]; then
   echo "[err] No device specified, aborting..."
   exit 1
fi

if [ "x${VOLUMIOIMAGE}" == "x" ]; then
   echo "[err] No Volumio image supplied, aborting..."
   exit 1
fi

if [ "x${VERSION}" == "x" ]; then
   echo "[warn] Warning: no flash image version supplied, continuing..."
fi

source "${SRC}/installer/board-config/${DEVICE}/mkinstall_config.sh"

PLTDIR="$SRC/platform-${DEVICEBASE}"
if [ -d "$SRC/build/$BUILD" ]; then
   if [ ! -d "${PLTDIR}" ]; then
      echo "No platform folder present, please build a volumio device image first"
	  exit 1
   fi
else
   echo "No ${BUILD} rootfs present, please build an image first"
   exit 1
fi

BUILDDATE=$(date -I)
IMG_FILE="AutoFlash${VERSION}-${BUILDDATE}-${DEVICE}.img"
VOLMNT=/mnt/volumio

echo "[Stage 1] Creating AutoFlash Image File ${IMG_FILE}"

dd if=/dev/zero of=${IMG_FILE} bs=1M count=1000

echo "[info] Creating Image Bed"
LOOP_DEV=`losetup -f --show ${IMG_FILE}`
# Note: leave the first 20Mb free for the firmware
parted -s "${LOOP_DEV}" mklabel ${BOOT_TYPE}
parted -s "${LOOP_DEV}" mkpart primary fat16 21 100%
parted -s "${LOOP_DEV}" set 1 boot on
partprobe "${LOOP_DEV}"
kpartx -s -a "${LOOP_DEV}"

FLASH_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
if [ ! -b "${FLASH_PART}" ]
then
   echo "[err] ${FLASH_PART} doesn't exist"
   exit 1
fi

echo "[info] Creating boot and rootfs filesystem"
mkfs -t vfat -n BOOT "${FLASH_PART}"

echo "[info] Preparing for the  kernel/ platform files"
if [ ! "x$NONSTANDARD_REPO" == "x" ]; then
   non_standard_repo
else
   HAS_PLTDIR=no
   if [ -d ${PLTDIR} ]; then
      pushd ${PLTDIR}
      # it should not happen that the 
      if [ -d ${BOARDFAMILY} ]; then
         HAS_PLTDIR=yes
      fi
      popd
   fi
   if [ $HAS_PLTDIR == no ]; then
      # This should normally not happen, just handle it for safety
      if [ -d ${PLTDIR} ]; then
         rm -r ${PLTDIR}  
	  fi
      echo "[info] Clone platform files from repo"
      git clone $PLATFORMREPO
      echo "[info] Unpacking the platform files"
      pushd $PLTDIR
      tar xfJ ${BOARDFAMILY}.tar.xz
      rm ${BOARDFAMILY}.tar.xz
      popd
   fi
fi

echo "[info] Writing the bootloader"
write_device_bootloader

sync

echo "[info] Preparing for Volumio rootfs"
if [ -d /mnt ]
then
	echo "[info] /mount folder exist"
else
	mkdir /mnt
fi
if [ -d $VOLMNT ]
then
	echo "[info] Volumio Temp Directory Exists - Cleaning it"
	rm -rf $VOLMNT/*
else
	echo "[info] Creating Volumio Temp Directory"
	mkdir $VOLMNT
fi

echo "[info] Creating mount points"
ROOTFSMNT=$VOLMNT/rootfs
mkdir $ROOTFSMNT
mkdir $ROOTFSMNT/boot
mount -t vfat "${FLASH_PART}" $ROOTFSMNT/boot

echo "[info] Copying RootFs"
cp -pdR ${SRC}/build/$BUILD/root/* $ROOTFSMNT
mkdir $ROOTFSMNT/root/scripts

echo "[info] Copying initrd config"
echo "BOOT_TYPE=${BOOT_TYPE}   
BOOT_START=${BOOT_START}
BOOT_END=${BOOT_END}
IMAGE_END=${IMAGE_END}
BOOT=${BOOT}
BOOTDELAY=${BOOTDELAY}
BOOTDEV=${BOOTDEV}
BOOTPART=${BOOTPART}
BOOTCONFIG=${BOOTCONFIG}
TARGETBOOT=${TARGETBOOT}
TARGETDEV=${TARGETDEV}
TARGETDATA=${TARGETDATA}
TARGETIMAGE=${TARGETIMAGE}
HWDEVICE=${HWDEVICE}
USEKMSG=${USEKMSG}
UUIDFMT=${UUIDFMT}
LBLBOOT=${LBLBOOT}
LBLIMAGE=${LBLIMAGE}
LBLDATA=${LBLDATA}
" > $ROOTFSMNT/root/scripts/initconfig.sh

echo "[info] Copying initrd scripts"   
cp ${SRC}/installer/board-config/${DEVICE}/board-functions $ROOTFSMNT/root/scripts
cp ${SRC}/installer/runtime-generic/gen-functions $ROOTFSMNT/root/scripts
cp ${SRC}/installer/runtime-generic/init-script $ROOTFSMNT/root/init
cp ${SRC}/installer/mkinitrd.sh $ROOTFSMNT

echo "[info] Copying kernel modules"
cp -pdR ${PLTDIR}/$BOARDFAMILY/lib/modules $ROOTFSMNT/lib/

echo "[info] writing board-specific files"
write_device_files

echo "[info] Writing board-specific boot parameters"
write_boot_parameters

sync

echo "[Stage 2] Run chroot to create an initramfs"
cp scripts/initramfs/mkinitramfs-custom.sh $ROOTFSMNT/usr/local/sbin

echo "
RAMDISK_TYPE=${RAMDISK_TYPE}
MODULES=($(printf '\"%s\" ' "${MODULES[@]}"))
PACKAGES=($(printf '\"%s\" ' "${PACKAGES[@]}"))
" > $ROOTFSMNT/config.sh


mount /dev $ROOTFSMNT/dev -o bind
mount /proc $ROOTFSMNT/proc -t proc
mount /sys $ROOTFSMNT/sys -t sysfs

chroot $ROOTFSMNT /bin/bash -x <<'EOF'
su -
/mkinitrd.sh
EOF

if [ "x${RAMDISK_TYPE}" == "ximage" ]; then
   echo "Creating uInitrd from 'volumio.initrd'"
   mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d $ROOTFSMNT/boot/volumio.initrd $ROOTFSMNT/boot/uInitrd
   rm $ROOTFSMNT/boot/volumio.initrd
fi

#cleanup
rm -r $ROOTFSMNT/mkinitrd.sh $ROOTFSMNT/config.sh  $ROOTFSMNT/root/init $ROOTFSMNT/root/scripts

echo "[Stage 3] Creating Volumio boot & image data folder"
mkdir -p $ROOTFSMNT/boot/data/boot
mkdir -p $ROOTFSMNT/boot/data/image

if [ -d /mnt/volumioimage ]
then
	echo "[info] Volumio Image mountpoint exists - Cleaning it"
	rm -rf /mnt/volumioimage/*
else
	echo "[info] Creating Volumio Image mountpoint"
	mkdir /mnt/volumioimage
fi

echo "[info] Create loopdevice for mounting volumio image"
LOOP_DEV1=$(losetup -f)
losetup -P ${LOOP_DEV1} ${VOLUMIOIMAGE}
BOOT_PART=${LOOP_DEV1}p1
IMAGE_PART=${LOOP_DEV1}p2

echo "[info] Mount volumio image partitions"
mkdir -p /mnt/volumioimage/boot
mkdir -p /mnt/volumioimage/image
mount -t vfat "${BOOT_PART}" /mnt/volumioimage/boot
mount -t ext4 "${IMAGE_PART}" /mnt/volumioimage/image

copy_device_bootloader_files

echo "[info] Copying 'raw' boot & image data"
#cd /mnt/volumioimage/boot
tar cfJ $ROOTFSMNT/boot/data/boot/kernel_current.tar.xz --exclude='resize-volumio-datapart' -C /mnt/volumioimage/boot .

cp /mnt/volumioimage/image/* /mnt/volumio/rootfs/boot/data/image

umount -l /mnt/volumioimage/boot
umount -l /mnt/volumioimage/image
rm -r /mnt/volumioimage

echo "[info] Unmounting Temp devices"
umount -l $ROOTFSMNT/dev
umount -l $ROOTFSMNT/proc
umount -l $ROOTFSMNT/sys
umount -l $ROOTFSMNT/boot

echo "[info] Removing Rootfs"
rm -r $ROOTFSMNT/*

sync

dmsetup remove_all
losetup -d ${LOOP_DEV1}
losetup -d ${LOOP_DEV}
echo "[info] Done..."
#rm $VOLUMIOIMAGE
sync
