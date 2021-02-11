#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Polyvection Voltastream Zero  (Community Portings)
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

## Images will not be pusblished

## WIP, this should be refactored out to a higher level.
# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm"

### Device information
DEVICENAME="Voltastream Zero"
DEVICE="vszero"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="pv"
# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=yes
VOLINITUPDATER=yes

## Partition info
BOOT_START=1
BOOT_END=64
BOOT_TYPE=msdos  # msdos or gpt
BOOT_USE_UUID=no # Add UUID to fstab
INIT_TYPE="init" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
# PACKAGES=("u-boot-tools")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICEBASE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -dR "${PLTDIR}/${DEVICEBASE}/lib/firmware" "${ROOTFSMNT}/lib/"

  log "Add hotspot"
  cp "${PLTDIR}/${DEVICEBASE}/bin/hotspot.sh" "${ROOTFSMNT}/bin"

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  dd if=${PLTDIR}/${DEVICEBASE}/u-boot/u-boot-dtb.imx-512Mb of=${LOOP_DEV} seek=1 bs=1k conv=notrunc
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

### Chroot tweaks
# Will be run in chroot (before other things)
device_chroot_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  sed -i "s/mmcblk0p1/mmcblk1p1/g" /etc/fstab
  log "Enable getty on ttyGS0"
  systemctl enable serial-getty@ttyGS0.service
  cat /etc/fstab

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  # log "Running device_chroot_tweaks_post" "ext"
  :
}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
  log "Running device_image_tweaks_post" "ext"
  log "Creating uInitrd from 'volumio.initrd'" "info"
  if [[ -f "${ROOTFSMNT}"/boot/volumio.initrd ]]; then
    mkimage -v -A "${UINITRD_ARCH}" -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d "${ROOTFSMNT}"/boot/volumio.initrd "${ROOTFSMNT}"/boot/uInitrd
    rm "${ROOTFSMNT}"/boot/volumio.initrd
  fi
}
