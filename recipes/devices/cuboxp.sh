#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Solidrun Cubox Pulse  (Community Portings)
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

## Images will not be published

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm64"

### Device information
DEVICENAME="Cubox Pulse"
DEVICE="cuboxp"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="cubox"
# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="https://github.com/gkkpch/platform-${DEVICEFAMILY}.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes

## Partition info
BOOT_START=21
BOOT_END=84
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
# PACKAGES=("u-boot-tools" "device-tree-compiler")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICEBASE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"
}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  sudo dd if="${PLTDIR}/${DEVICEBASE}/uboot/u-boot.bin" of=${LOOP_DEV} bs=1024 seek=33
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

  log "Modifying uEnv.txt template"
  sed -i "s/%%BOOT-SD%%/bootdev=mmcblk1 bootpart=\/dev\/mmcblk1p1 imgpart=\/dev\/mmcblk1p2 datapart=\/dev\/mmcblk1p3/g" /boot/uEnv.txt
  sed -i "s/%%BOOT-EMMC%%/imgpart=\/dev\/mmcblk0p2 bootdev=mmcblk0/g" /boot/uEnv.txt
  sed -i "s/%%BOOT-EMMC%%/bootdev=mmcblk0 bootpart=\/dev\/mmcblk0p1 imgpart=\/dev\/mmcblk0p2 datapart=\/dev\/mmcblk0p3/g" /boot/uEnv.txt

  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >/etc/sysctl.conf
abi.cp15_barrier=2
EOF

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
  if [[ -f "${ROOTFSMNT}"/boot/boot.cmd ]]; then
    log "Creating boot.scr"
    mkimage -A "${UINITRD_ARCH}" -T script -C none -d "${ROOTFSMNT}"/boot/boot.cmd "${ROOTFSMNT}"/boot/boot.scr
  fi
}
