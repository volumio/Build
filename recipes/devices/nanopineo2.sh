#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for NanoPi Neo2 H5 based devices
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="arm64"
BUILD="armv8"
UINITRD_ARCH="arm64"

### Device information
DEVICENAME="NanoPi Neo2"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="nanopi"
# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="https://github.com/ashthespy/platform-${DEVICEFAMILY}"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes

## Partition info
BOOT_START=21
BOOT_END=84
BOOT_TYPE=msdos          # msdos or gpt
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "overlayfs" "squashfs" "nls_cp437" "fuse")
# Packages that will be installed
# PACKAGES=("u-boot-tools")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/firmware" "${ROOTFSMNT}/lib"
  # log "Setting sun50i-h5-nanopi-neo2-i2s-generic.dtb version as default"
  # mv ${ROOTFSMNT}/boot/sun50i-h5-nanopi-neo2.dtb \
  #     ${ROOTFSMNT}/boot/sun50i-h5-nanopi-neo2-org-default.dtb
  # mv ${ROOTFSMNT}/boot/sun50i-h5-nanopi-neo2-i2s-generic.dtb \
  #     ${ROOTFSMNT}/boot/sun50i-h5-nanopi-neo2.dtb
}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICE}/u-boot/sunxi-spl.bin" of="${LOOP_DEV}" bs=1024 seek=8
  dd if="${PLTDIR}/${DEVICE}/u-boot/u-boot.itb" of="${LOOP_DEV}" bs=1024 seek=40
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Adding gpio group and udev rules"
  groupadd -f --system gpio
  usermod -aG gpio volumio
  #TODO: Refactor to cat
  touch /etc/udev/rules.d/99-gpio.rules
  echo "SUBSYSTEM==\"gpio\", ACTION==\"add\", RUN=\"/bin/sh -c '
          chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio;\
          chown -R root:gpio /sys$DEVPATH && chmod -R 770 /sys$DEVPATH    '\"" >/etc/udev/rules.d/99-gpio.rules
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
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
    mkimage -A arm -T script -C none -d "${ROOTFSMNT}"/boot/boot.cmd "${ROOTFSMNT}"/boot/boot.scr
  fi
}
