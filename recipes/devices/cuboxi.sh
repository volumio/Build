#!/usr/bin/env bash
# shellcheck disable=SC2034
## Setup for Solidrun Cuboxi

## WIP, this should be refactored out to a higher level.
# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"

### Device information
DEVICENAME="Cuboxi"
DEVICE="cuboxi"
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
BOOT_START=1
BOOT_END=64
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=no         # Add UUID to fstab
INIT_TYPE="init" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("u-boot-tools" "device-tree-compiler")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICEBASE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -dR "${PLTDIR}/${DEVICEBASE}/usr/src" "${ROOTFSMNT}/usr"
  cp "${PLTDIR}/${DEVICEBASE}/nvram-fw/brcmfmac4329-sdio.txt" "${ROOTFSMNT}/lib/firmware/brcm/"
  cp "${PLTDIR}/${DEVICEBASE}/nvram-fw/brcmfmac4330-sdio.txt" "${ROOTFSMNT}/lib/firmware/brcm/"

  log "Add alsa config"
  cp "${PLTDIR}/${DEVICEBASE}/usr/share/alsa/cards/imx-hdmi-soc.conf" "${ROOTFSMNT}/usr/share/alsa/cards"
  cp "${PLTDIR}/${DEVICEBASE}/usr/share/alsa/cards/imx-spdif.conf" "${ROOTFSMNT}/usr/share/alsa/cards"
  cp "${PLTDIR}/${DEVICEBASE}/usr/share/alsa/cards/aliases.conf" "${ROOTFSMNT}/usr/share/alsa/cards"
  chown root:root "${ROOTFSMNT}/usr/share/alsa/cards/imx-hdmi-soc.conf"
  chown root:root "${ROOTFSMNT}/usr/share/alsa/cards/imx-spdif.conf"
  chown root:root "${ROOTFSMNT}/usr/share/alsa/cards/aliases.conf"

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  dd if="${PLTDIR}/${DEVICEBASE}/uboot/SPL" of=${LOOP_DEV} bs=1K seek=1
  dd if="${PLTDIR}/${DEVICEBASE}/uboot/u-boot.img" of=${LOOP_DEV} bs=1K seek=42
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

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  log "Creating uInitrd from 'volumio.initrd'" "info"
  #TODO This can be done outside chroot,
  # removing the need of each image needing u-boot-tools
  # saving some time!
  mkimage -v -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
  log "Removing unnecessary /boot files"
  rm /boot/volumio.initrd
}
