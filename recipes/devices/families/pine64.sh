#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Pine64 family of devices

## WIP, this should be refactored out to a higher level.
# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"

### Device information

DEVICEBASE="pine64-all"
DEVICEFAMILY="pine64"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEREPO="https://github.com/volumio/platform-pine64.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=yes
VOLINITUPDATER=no
KIOSKMODE=no

## Partition info
BOOT_START=2
BOOT_END=64
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("u-boot-tools" "liblircclient0" "lirc" "libcdio-dev" "libcdparanoia-dev" "bluez-firmware" "bluetooth" "bluez" "bluez-tools")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp ${PLTDIR}/${DEVICEBASE}/boot/Image ${ROOTFSMNT}/boot
  cp -dR ${PLTDIR}/${DEVICEBASE}/boot/dtb ${ROOTFSMNT}/boot
  
  log "Copying kernel configuration file"
  cp ${PLTDIR}/${DEVICEBASE}/boot/config* ${ROOTFSMNT}/boot

  log "Copying kernel modules"
  cp -pdR ${PLTDIR}/${DEVICEBASE}/lib/modules ${ROOTFSMNT}/lib/

  log "Confguring ALSA with sane defaults"
  cp ${PLTDIR}/${DEVICEBASE}/var/lib/alsa/* ${ROOTFSMNT}/var/lib/alsa

  log "Copying firmware"
  cp -R ${PLTDIR}/${DEVICEBASE}/firmware/* ${ROOTFSMNT}/lib/firmware

  log "Adding 'unmute headphone' script"
  cp ${PLTDIR}/${DEVICEBASE}/etc/rc.local ${ROOTFSMNT}/etc
  chmod +x ${ROOTFSMNT}/etc/rc.local

  log "Copying boot script & uboot environment configuration extension"
  cp ${PLTDIR}/${DEVICEBASE}/boot/boot.cmd ${ROOTFSMNT}/boot
  cp ${PLTDIR}/${DEVICEBASE}/boot/uEnv.txt.${DEVICE} ${ROOTFSMNT}/boot/uEnv.txt

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  log "Copying specific (u)boot files"
  dd if=${PLTDIR}/${DEVICEBASE}/u-boot/${UBOOT_VARIANT}/sunxi-spl.bin of=${LOOP_DEV} conv=fsync bs=8k seek=1
  dd if=${PLTDIR}/${DEVICEBASE}/u-boot/${UBOOT_VARIANT}/u-boot.itb of=${LOOP_DEV} conv=fsync bs=8k seek=5
  
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >>/etc/sysctl.conf
abi.cp15_barrier=2
EOF

  log "Enabling Bluetooth Adapter auto-poweron"
  cat <<-EOF >> /etc/bluetooth/main.conf 
[Policy]
AutoEnable=true
EOF

  log "Changing initramfs module config to 'modules=list' to limit uInitrd size" "cfg"
  sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  #TODO This can be done outside chroot,
  # removing the need of each image needing u-boot-tools
  # saving some time!

  log "Creating boot script from boot.cmd"
  mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr

  if [[ -f /boot/volumio.initrd ]]; then
    log "Creating uInitrd from 'volumio.initrd'" "info"
    mkimage -v -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
    rm /boot/volumio.initrd
  fi
}
