#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid C4 device  (Community Portings)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"

### Device information
DEVICEFAMILY="odroid"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEREPO="https://github.com/volumio/platform-odroid.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=yes
VOLINITUPDATER=yes
KIOSKMODE=no

## Partition info
BOOT_START=1
BOOT_END=64
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("u-boot-tools" "lirc" "fbset")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp ${PLTDIR}/${DEVICEBASE}/boot/*.ini "${ROOTFSMNT}/boot"
  cp -dR "${PLTDIR}/${DEVICEBASE}/boot/amlogic" "${ROOTFSMNT}/boot"
  cp "${PLTDIR}/${DEVICEBASE}/boot/Image.gz" "${ROOTFSMNT}/boot"
  cp ${PLTDIR}/${DEVICEBASE}/boot/config-* "${ROOTFSMNT}/boot"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/firmware" "${ROOTFSMNT}/lib"

  echo "Copying rc.local for ${DEVICENAME} performance tweaks"
  cp "${PLTDIR}/${DEVICEBASE}/etc/rc.local" "${ROOTFSMNT}/etc"

  log "Copying LIRC configuration files for HK stock remote"
  cp "${PLTDIR}/${DEVICEBASE}/etc/lirc/lircd.conf" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICEBASE}/etc/lirc/hardware.conf" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICEBASE}/etc/lirc/lircrc" "${ROOTFSMNT}"

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICEBASE}/uboot/u-boot.bin" of="${LOOP_DEV}" conv=fsync,notrunc bs=512 seek=1
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Creating boot.ini from template"
  sed -i "s/%%VOLUMIO-PARAMS%%/imgpart=UUID=${UUID_IMG} bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA}/" /boot/boot.ini

  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >>/etc/sysctl.conf
abi.cp15_barrier=2
EOF
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  log "Configuring HK stock remote"
  cp lircd.conf /etc/lirc
  cp hardware.conf /etc/lirc
  cp lircrc /etc/lirc
  rm lircd.conf hardware.conf lircrc

  #TODO This can be done outside chroot,
  # removing the need of each image needing u-boot-tools
  # saving some time!
  if [[ -f /boot/volumio.initrd ]]; then
    log "Creating uInitrd from 'volumio.initrd'" "info"
    mkimage -v -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
    rm /boot/volumio.initrd
  fi
}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
  # log "Running device_chroot_tweaks_post" "ext"
  :
}
