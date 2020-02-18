#!/bin/bash

set -eo

function exit_error()
{
  log "Volumio imagebuilder failed" "$(basename "$0")" "err"
}

trap exit_error INT ERR

# Default build for Debian 32bit
ARCH="armv8"

while getopts ":d:v:p:a:" opt; do
  case $opt in
    d)
      DEVICE=$OPTARG
      ;;
    v)
      VERSION=$OPTARG
      ;;
    p)
      PATCH=$OPTARG
      ;;
    a)
      ARCH=$OPTARG
      ;;
      *)
      log "Unknown flag ${OPTARG}" "err" "$(basename "$0")"
  esac
done

BUILDDATE=$(date -I)
IMG_FILE="Volumio_${VERSION}-${BUILDDATE}-${DEVICE}.img"
export IMG_FILE

log "Creating Image File ${IMG_FILE} with $ARCH rootfs" "info"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800

log "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`

# Note: leave the first 20Mb free for the firmware
parted -s "${LOOP_DEV}" mklabel msdos
parted -s "${LOOP_DEV}" mkpart primary fat32 20 84
parted -s "${LOOP_DEV}" mkpart primary ext3 84 2500
parted -s "${LOOP_DEV}" mkpart primary ext3 2500 100%
parted -s "${LOOP_DEV}" set 1 boot on
parted -s "${LOOP_DEV}" print
partprobe "${LOOP_DEV}"
kpartx -s -a "${LOOP_DEV}"

BOOT_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
SYS_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
DATA_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p3`

if [ ! -b "${BOOT_PART}" ]
then
	log "${BOOT_PART} doesn't exist" "err"
	exit 1
fi

log "Creating boot and rootfs filesystems" "info"
mkfs -t vfat -n BOOT "${BOOT_PART}"
mkfs -F -t ext4 -L volumio "${SYS_PART}"
mkfs -F -t ext4 -L volumio_data "${DATA_PART}"
sync

log "Preparing for the ROCK Pi S kernel/platform files" "info"
if [ -d platform-rockpis ]
then
	log "Platform folder already exists - keeping it"
else
	log "Clone all ROCK Pi S files from repo"
	# git clone https://github.com/ashthespy/platform-rockpis.git platform-rockpis
  cp ../../platform-rockpis/rockpi-s.tar.xz ./platform-rockpis
	log "Unpack the ROCK Pi S platform files"
	cd platform-rockpis
	tar xfJ "rockpi-s.tar.xz"
  mv rockpi-s rockpis
	cd ..
fi

log "Burning the bootloader and u-boot" "info"
sudo dd if=platform-rockpis/rockpis/u-boot/idbloader.bin of=${LOOP_DEV} seek=64 conv=notrunc status=none
sudo dd if=platform-rockpis/rockpis/u-boot/uboot.img of=${LOOP_DEV} seek=16384 conv=notrunc status=none
sudo dd if=platform-rockpis/rockpis/u-boot/trust.bin of=${LOOP_DEV} seek=24576 conv=notrunc status=none
sync

log "Preparing for Volumio rootfs" "info"
if [ -d /mnt ]
then
	log "/mount folder exist"
else
	mkdir /mnt
fi

if [ -d /mnt/volumio ]
then
	log "Volumio Temp Directory Exists - Cleaning it"
	rm -rf /mnt/volumio/*
else
	log "Creating Volumio Temp Directory"
	sudo mkdir /mnt/volumio
fi

log "Creating mount point for the images partition"
mkdir /mnt/volumio/images
mount -t ext4 "${SYS_PART}" /mnt/volumio/images
mkdir /mnt/volumio/rootfs
log "Creating mount point for the boot partition"
mkdir /mnt/volumio/rootfs/boot
mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot

log "Copying Volumio RootFs" "info"
cp -pdR build/$ARCH/root/* /mnt/volumio/rootfs

log "Copying ROCK Pi S boot files, kernel, modules and firmware"
cp -dR platform-rockpis/${DEVICE}/boot /mnt/volumio/rootfs
cp -pdR platform-rockpis/${DEVICE}/lib/modules /mnt/volumio/rootfs/lib
cp -pdR platform-rockpis/${DEVICE}/lib/firmware /mnt/volumio/rootfs/lib

log "Preparing to run chroot for more ROCK Pi S configuration" "info"
start_chroot_final=$(date +%s)
cp scripts/rockpisconfig.sh /mnt/volumio/rootfs
cp scripts/initramfs/init.nextarm /mnt/volumio/rootfs/root/init
cp scripts/initramfs/mkinitramfs-buster.sh /mnt/volumio/rootfs/usr/local/sbin
cp scripts/helpers.sh /mnt/volumio/rootfs
#copy the scripts for updating from usb
wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs
echo $PATCH > /mnt/volumio/rootfs/patch

log "Grab UUIDS"
echo "UUID_DATA=$(blkid -s UUID -o value ${DATA_PART})
UUID_IMG=$(blkid -s UUID -o value ${SYS_PART})
UUID_BOOT=$(blkid -s UUID -o value ${BOOT_PART})
" > /mnt/volumio/rootfs/root/init.sh
chmod +x /mnt/volumio/rootfs/root/init.sh

chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/rockpisconfig.sh
EOF

#cleanup
rm /mnt/volumio/rootfs/rockpisconfig.sh /mnt/volumio/rootfs/root/init
rm /mnt/volumio/rootfs/helpers.sh

end_chroot_final=$(date +%s)
time_it $end_chroot_final $start_chroot_final
log "Finished chroot image configuration" "okay" "$time_str"

log "Unmounting chroot tmp devices" "info"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys

sync

log "Finalizing Rootfs creation" "info"
sh scripts/finalize.sh
log "Rootfs created" "okay"

log "Preparing rootfs base for SquashFS" "info"

if [ -d /mnt/squash ]; then
	log "Volumio SquashFS Temp Dir Exists - Cleaning it"
	rm -rf /mnt/squash/*
else
	log "Creating Volumio SquashFS Temp Dir"
	mkdir /mnt/squash
fi

log "Copying Volumio rootfs to Temp Dir"
cp -rp /mnt/volumio/rootfs/* /mnt/squash/

if [ -e /mnt/kernel_current.tar ]; then
	log "Volumio Kernel Partition Archive exists - Cleaning it"
	rm -rf /mnt/kernel_current.tar
fi

log "Creating Kernel Partition Archive"
tar cf /mnt/kernel_current.tar  -C /mnt/squash/boot/ .

log "Removing the Kernel"
rm -rf /mnt/squash/boot/*

log "Creating SquashFS, removing any previous one" "info"
rm -r Volumio.sqsh
mksquashfs /mnt/squash/* Volumio.sqsh

log "Squash filesystem created" "okay"
rm -rf /mnt/squash

log "Preparing boot partition" "info"
#copy the squash image inside the boot partition
cp Volumio.sqsh /mnt/volumio/images/volumio_current.sqsh
sync
log "Unmounting Temp Devices" "okay"
umount -l /mnt/volumio/images
umount -l /mnt/volumio/rootfs/boot

dmsetup remove_all
losetup -d ${LOOP_DEV}
sync

log "Hashing image" "info"
md5sum "$IMG_FILE" > "${IMG_FILE}.md5"
