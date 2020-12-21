#!/usr/bin/env bash
# shellcheck disable=SC2034
## Setup for Radxa Rock Pi S

## WIP, this should be refactored out to a higher level.
# Base system
BASE="Debian"
#ARCH="arm64"
#BUILD="armv8"
ARCH="armhf"
BUILD="armv7"

### Device information
DEVICENAME="ROCK Pi S"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEBASE="rockpis"
DEVICEREPO="https://github.com/ashthespy/platform-rockpis.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=no

## Partition info
BOOT_START=20
BOOT_END=84
BOOT_TYPE=msdos          # msdos or gpt
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "overlayfs" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("u-boot-tools")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/firmware" "${ROOTFSMNT}/lib"
}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICE}/u-boot/idbloader.bin" of="${LOOP_DEV}" seek=64 conv=notrunc status=none
  dd if="${PLTDIR}/${DEVICE}/u-boot/uboot.img" of="${LOOP_DEV}" seek=16384 conv=notrunc status=none
  dd if="${PLTDIR}/${DEVICE}/u-boot/trust.bin" of="${LOOP_DEV}" seek=24576 conv=notrunc status=none
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
  log "Running device_chroot_tweaks_post" "ext"

  log "Creating uInitrd from 'volumio.initrd'" "info"
  #TODO This can be done outside chroot,
  # removing the need of each image needing u-boot-tools
  # saving some time!
  if [[ -f /boot/volumio.initrd ]]; then
    [[ $ARCH == "armhf" ]] && ARCH="arm"
    mkimage -v -A $ARCH -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
  fi
  if [[ ! -f /boot/boot.scr ]]; then
    log "Creating boot.scr"
    [[ $ARCH == "armhf" ]] && ARCH="arm"
    mkimage -A $ARCH -T script -C none -d /boot/boot.cmd /boot/boot.scr
  fi
}
