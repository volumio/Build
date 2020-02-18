#!/usr/bin/env bash
## Setup for Radxa Rock Pi S

## WIP, this should be refactored out to a higher level.
# Base system
BASE=Debian
ARCH=arm64
BUILD=armv8 #

### Device information
DEVICENAME="ROCK Pi S"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEBASE="rockpis"
DEVICEREPO="https://github.com/ashthespy/platform-rockpis.git"

### What features do we want to target
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=no

# Modules that will be added to intramsfs
MODULES=("overlay" "overlayfs" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("winbind" "u-boot-tools")


### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  cp -dR ${platform_dir}/${DEVICE}/boot ${ROOTFSMNT}
  cp -pdR ${platform_dir}/${DEVICE}/lib/modules ${ROOTFSMNT}/lib
  cp -pdR ${platform_dir}/${DEVICE}/lib/firmware ${ROOTFSMNT}/lib
}

write_device_bootloader(){
  dd if="${platform_dir}/${DEVICE}/u-boot/idbloader.bin" of=${LOOP_DEV} seek=64 conv=notrunc status=none
  dd if="${platform_dir}/${DEVICE}/u-boot/uboot.img" of=${LOOP_DEV} seek=16384 conv=notrunc status=none
  dd if="${platform_dir}/${DEVICE}/u-boot/trust.bin" of=${LOOP_DEV} seek=24576 conv=notrunc status=none
}

# Will be called by the image builder for any customisation
device_image_tweaks(){
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
          chown -R root:gpio /sys$DEVPATH && chmod -R 770 /sys$DEVPATH\
    '\"" > /etc/udev/rules.d/99-gpio.rules
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post(){
  :
}
