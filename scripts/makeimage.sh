#!/usr/bin/env bash
# Image creating script


log "Stage [2]: Creating Image" "info"
log "Image file: ${IMG_FILE}"


# Pick the parition scheme from board conf -
dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`

sudo parted -s "${LOOP_DEV}" mklabel msdos
sudo parted -s "${LOOP_DEV}" mkpart primary fat32 0 64 # Might need to be made bigger!
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 64 2500
sudo parted -s "${LOOP_DEV}" mkpart primary ext3 2500 2800
sudo parted -s "${LOOP_DEV}" set 1 boot on
sudo parted -s "${LOOP_DEV}" print
sudo partprobe "${LOOP_DEV}"
sudo kpartx -a "${LOOP_DEV}" -s

BOOT_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
IMG_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
DATA_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p3`
if [ ! -b "$BOOT_PART" ]
then
	echo "$BOOT_PART doesn't exist"
	exit 1
fi
