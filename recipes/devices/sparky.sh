#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Allo Sparky device  (Community Portings)

## WIP, this should be refactored out to a higher level.
# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"

### Device information
DEVICE="sparky"
DEVICEFAMILY="sparky"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=yes
VOLINITUPDATER=yes
KIOSKMODE=no

## Partition info
BOOT_START=8
BOOT_END=71
BOOT_TYPE=msdos          # msdos or gpt
FLAGS_EXT4=("-O" "^metadata_csum,^64bit") # Disable ext4 metadata checksums
BOOT_USE_UUID=no        # Add UUID to fstab
INIT_TYPE="init" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlayfs" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("u-boot-tools")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  log "Copying ${DEVICENAME} boot files"
  cp -dR ${PLTDIR}/${DEVICEBASE}/boot ${ROOTFSMNT}
  log "Copying ${DEVICENAME} modules and firmware"
  cp -pdR ${PLTDIR}/${DEVICEBASE}/lib/modules ${ROOTFSMNT}/lib/
  cp -pdR ${PLTDIR}/${DEVICEBASE}/lib/firmware ${ROOTFSMNT}/lib/
  log "Copying special hotspot.sh version for Sparky"
  cp ${PLTDIR}/${DEVICEBASE}/bin/hotspot.sh ${ROOTFSMNT}/bin

  log "Copying DSP firmware and license from allocom dsp git"
# doing this here and not in config because cloning under chroot caused issues before"
  git clone http://github.com/allocom/piano-firmware allo
  cp -pdR allo/lib ${ROOTFSMNT}
  rm -r allo

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  dd if=${PLTDIR}/${DEVICEBASE}/u-boot/bootloader.bin of=${LOOP_DEV} bs=512 seek=4097
  dd if=${PLTDIR}/${DEVICEBASE}/u-boot/u-boot-dtb.img of=${LOOP_DEV} bs=512 seek=6144

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  log "device_image_tweaks() not used"
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Blacklisting noisy module"
  cat <<-EOF >/etc/modprobe.d/blacklist.conf
blacklist ctp_gsl3680
EOF

  wget  https://raw.githubusercontent.com/sparkysbc/downloads/master/wiringSparky.tgz
  tar -xzvf wiringSparky.tgz -C /
  rm wiringSparky.tgz

  log "Changing initramfs module config to 'modules=list' to limit uInitrd size" "cfg"
  sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  #TODO This can be done outside chroot,
  # removing the need of each image needing u-boot-tools
  # saving some time!
  if [[ -f /boot/volumio.initrd ]]; then
    log "Creating uInitrd from 'volumio.initrd'" "info"
    mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/ramdisk.img
    rm /boot/volumio.initrd
  fi
}
