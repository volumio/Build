#!/usr/bin/env bash
# Image creating script

set -eo pipefail

exit_error () {
  log "Imagebuilder script failed!!" "err"
  # Check if there are any mounts that need cleaning up
  # If dev is mounted, the rest should also be mounted (right?)
  if isMounted "$rootfs/dev"; then
    unmount_chroot
  fi

  # dmsetup remove_all
  log "Cleaning loop device $LOOP_DEV"
  losetup -d ${LOOP_DEV}
  dmsetup remove ${LOOP_DEV}
  log "Deleting image file"
  rm ${IMG_FILE}
}

trap exit_error INT ERR

log "Stage [2]: Creating Image" "info"
log "Image file: ${IMG_FILE}"
VOLMNT=/mnt/volumio
#TOOD Pick the parition scheme(size?) from board conf
#TODO boot partition might need to be bigger, rPi arleady is touch and go
dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800
LOOP_DEV=$(losetup -f --show ${IMG_FILE})

parted -s "${LOOP_DEV}" mklabel msdos
parted -s "${LOOP_DEV}" mkpart primary fat32 0 64
parted -s "${LOOP_DEV}" mkpart primary ext3 64 2500
parted -s "${LOOP_DEV}" mkpart primary ext3 2500 2800
parted -s "${LOOP_DEV}" set 1 boot on
parted -s "${LOOP_DEV}" print
partprobe "${LOOP_DEV}"
kpartx -a "${LOOP_DEV}" -s

BOOT_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
IMG_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
DATA_PART=`echo /dev/mapper/"$( echo $LOOP_DEV | sed -e 's/.*\/\(\w*\)/\1/' )"p3`

if [[ ! -b "$BOOT_PART" ]]; then
  log "$BOOT_PART doesn't exist" "err"
  exit 1
fi

log "Creating filesystem" "info"
mkfs -t vfat -n BOOT "${BOOT_PART}"
mkfs -F -t ext4 -L volumio "${IMG_PART}"
mkfs -F -t ext4 -L volumio_data "${DATA_PART}"
#sync

log "Copying Volumio rootfs" "info"

if [[ -d $VOLMNT ]]; then
  log "Volumio Temp Directory Exists - Cleaning it"
  rm -rf ${VOLMNT:?}/*
else
  log "Creating Volumio Temp Directory"
  mkdir -p $VOLMNT
fi

# Create mount point for image partitions
log "Creating mount point for the images partition"
rootfsmnt=$VOLMNT/rootfs
mkdir $VOLMNT/images
mkdir -p $rootfsmnt/boot
# Boot is vfat

mount -t ext4 "${IMG_PART}" $VOLMNT/images
mount -t vfat "${BOOT_PART}" $rootfsmnt/boot

#TODO -pPR?
cp -pdR $rootfs/* $rootfsmnt

# Refactor this to support more binaries
if [[ $VOLINITUPDATER == yes ]]; then
  log "Fetching volumio-init-updater"
  wget -P $rootfsmnt/usr/local/sbin http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater

fi

log "Getting device specific files for ${DEVICE} from platform-${DEVICEBASE}" "info"
platform_dir="$SRC/platform-${DEVICEBASE}"
if [[ -d $platform_dir ]]; then
  log "Platform folder exists, keeping it" "" "platform-${DEVICEBASE}"
else
  log "Cloning platform-${DEVICEBASE} from ${DEVICEREPO}"
  git clone --depth 1 $DEVICEREPO platform-${DEVICEBASE}
  log "Unpacking $DEVICE files"
  mkdir -p ${platform_dir}/${DEVICE}
  tar xfJ platform-${DEVICEBASE}/${DEVICE}.tar.xz -C ${platform_dir}/${DEVICE}
fi

# This is pulled in from each devices's config script
log "Copying ${DEVICE} boot files from platform-${DEVICEBASE}" "info"

write_device_files

log "Writing bootloader"

write_device_bootloader

# Device specific tweaks
log "Performing ${DEVICE} specific tweaks"
device_tweaks

# Ensure all filesystems oprations are completed before entering chroot again
sync

#### Build stage 2 - Device specific chroot config
log "Preparing to run chroot for more ${DEVICE} configuration" "info"
start_chroot_final=$(date +%s)
cp $SRC/scripts/initramfs/init.nextarm $rootfsmnt/root/init
cp $SRC/scripts/initramfs/mkinitramfs-buster.sh $rootfsmnt/usr/local/sbin
cp $SRC/scripts/volumio/chrootconfig.sh $rootfsmnt
echo $PATCH > $rootfsmnt/patch

# Copy across custom bits and bobs from device config
# This is in the hope that <./recipes/boards/${DEVICE}>
# doesn't grow back into the old <xxxxconfig.sh>

#TODO: Should we just copy the
# whole thing into the chroot to make life easier?
cat <<-EOF > $rootfsmnt/chroot_device_config.sh
DEVICENAME="${DEVICENAME}"
ARCH="${ARCH}"
MODULES=($(printf '\"%s\" ' "${MODULES[@]}"))
PACKAGES=($(printf '\"%s\" ' "${PACKAGES[@]}"))
$(declare -f device_chroot_tweaks_pre)
$(declare -f device_chroot_tweaks_post)
EOF

mount_chroot
## Enter chroot for last leg of config
# log "Grab UUIDS"
# echo "UUID_DATA=$(blkid -s UUID -o value ${DATA_PART})
# UUID_IMG=$(blkid -s UUID -o value ${SYS_PART})
# UUID_BOOT=$(blkid -s UUID -o value ${BOOT_PART})
# " > /mnt/volumio/rootfs/root/init.sh
# chmod +x /mnt/volumio/rootfs/root/init.sh

log "Calling final chroot config script"
chroot $rootfsmnt /bin/bash -x <<'EOF'
su -
/chrootconfig.sh
EOF
# Clean up chroot stuff
unmount_chroot
end_chroot_final=$(date +%s)
time_it $end_chroot_final $start_chroot_final
log "Finished chroot image configuration" "okay" "$time_str"

log "Finalizing Rootfs creation" "info"

# shellcheck source=./scripts/volumio/finalize.sh
source ${SRC}/scripts/volumio/finalize.sh

log "Rootfs created" "okay"


#### Build stage 3 - Prepare squashfs
log "Preparing rootfs base for SquashFS" "info"

SQSHMNT="$VOLMNT/squash"
if [[ -d $SQSHMNT ]]; then
  log "Volumio SquashFS Temp Dir Exists - Cleaning it"
  rm -rf ${SQSHMNT:?}/*
else
  log "Creating Volumio SquashFS Temp Dir at $SQSHMNT"
  mkdir $SQSHMNT
fi
log "Copying Volumio rootfs to SquashFS Dir"
cp -rp $rootfsmnt/* $SQSHMNT


log "Creating Kernel Partition Archive" "info"
if [ -e $VOLMNT/kernel_current.tar ]; then
  log "Volumio Kernel Partition Archive exists - Cleaning it"
  rm -rf $VOLMNT/kernel_current.tar
fi

log "Creating Kernel archive"
tar cf $VOLMNT/kernel_current.tar --exclude='resize-volumio-datapart'\
  -C $SQSHMNT/boot/ .

log "Removing the Kernel from SquashFS"
rm -rf ${SQSHMNT:?}/boot/*

log "Creating SquashFS, removing any previous one" "info"
[[ -f $SRC/Volumio.sqsh ]] && rm -r $SRC/Volumio.sqsh
mksquashfs $SQSHMNT/* $SRC/Volumio.sqsh

log "Squash filesystem created" "okay"
rm -rf --one-file-system $SQSHMNT

log "Preparing boot partition" "info"
#copy the squash image inside the boot partition
cp $SRC/Volumio.sqsh $VOLMNT/images/volumio_current.sqsh
sync

log "Unmounting devices" "info"
unmount -l $VOLMNT/images
unmount -l $rootfsmnt/boot

dmsetup remove_all
losetup -d ${LOOP_DEV}
sync

log "Hashing image" "info"
md5sum "$IMG_FILE" > "${IMG_FILE}.md5"
