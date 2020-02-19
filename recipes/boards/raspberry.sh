#!/usr/bin/env bash
# shellcheck disable=SC2034
## Setup for Radxa Rock Pi S

## WIP, this should be refactored out to a higher level.
# Base system
BASE="Raspbian"
ARCH="armhf"
BUILD="arm"

### Device information
DEVICENAME="Raspberry Pi"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEBASE="pi"
#DEVICEREPO=""

### What features do we want to target
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes

# Modules that will be added to intramsfs
MODULES=("overlay" "overlayfs" "squashfs" "nls_cp437" "i2c-dev")
# Packages that will be installed
PACKAGES=("binutils" "i2c-tools" \
          "bluez" "bluez-firmware" "pi-bluetooth"\ # Bluetooth packages
          "raspberrypi-sys-mods" \                 # Foundation stuff
          "i2c-tools" "wiringpi"\                  # GPIO stuff
          "plymouth" "plymouth-themes"\            # Boot splash
          )

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  :
}

write_device_bootloader(){
  :
}

# Will be called by the image builder for any customisation
device_image_tweaks(){
  log "Custom dtoverlay pre and post" "ext"
  mkdir -p ${ROOTFSMNT}/opt/vc/bin/
  cp -rp ${SRC}/volumio/opt/vc/bin/* ${ROOTFSMNT}/opt/vc/bin/
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post(){
  :
}
