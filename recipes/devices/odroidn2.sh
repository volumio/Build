#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid N2 device

## WIP, this should be refactored out to a higher level.
# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"

### Device information
DEVICENAME="Odroid N2"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEBASE="odroid"
DEVICEREPO="https://github.com/volumio/platform-odroid.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=no
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
  trap exit_error INT ERR
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/firmware" "${ROOTFSMNT}/lib"

  echo "Copying rc.local for Odroid N2 performance tweaks"
  cp "${PLTDIR}/${DEVICE}/etc/rc.local" "${ROOTFSMNT}/etc"

  log "Copying LIRC configuration files for HK stock remote"
  cp "${PLTDIR}/${DEVICE}/etc/lirc/lircd.conf" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICE}/etc/lirc/hardware.conf" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICE}/etc/lirc/lircrc" "${ROOTFSMNT}"

}

write_device_bootloader() {
  trap exit_error INT ERR
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICE}/uboot/u-boot.bin" of="${LOOP_DEV}" conv=fsync,notrunc bs=512 seek=1
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Creating boot.ini from template"
  sed -i "s/%%VOLUMIO-PARAMS%%/imgpart=UUID=${UUID_IMG} imgfile=\/volumio_current.sqsh hwdevice=Odroid-N2 bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA} bootconfig=boot.ini loglevel=0/" /boot/boot.ini

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
