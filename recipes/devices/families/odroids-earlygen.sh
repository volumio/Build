#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid C1/C2 device

## WIP, this should be refactored out to a higher level.
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
MYVOLUMIO=no
VOLINITUPDATER=no
KIOSKMODE=no

## Partition info
BOOT_START=1
BOOT_END=64
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=no        # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlayfs" "overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("u-boot-tools" "liblircclient0" "lirc" "fbset")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  log "Copying ${DEVICENAME} boot files"
  cp ${PLTDIR}/${DEVICE}/boot/boot.ini* ${ROOTFSMNT}/boot
  cp ${PLTDIR}/${DEVICE}/boot/${DTBFILENAME} ${ROOTFSMNT}/boot
  cp ${PLTDIR}/${DEVICE}/boot/${KERNELFILENAME} ${ROOTFSMNT}/boot

  log "Copying ${DEVICENAME}  modules and firmware"
  cp -pdR ${PLTDIR}/${DEVICE}/lib/modules ${ROOTFSMNT}/lib/
  cp -pdR ${PLTDIR}/${DEVICE}/lib/firmware ${ROOTFSMNT}/lib/

  log "Copying ${DEVICENAME}  DAC detection service"
  cp ${PLTDIR}/${DEVICE}/etc/odroiddac.service ${ROOTFSMNT}/lib/systemd/system/
  cp ${PLTDIR}/${DEVICE}/etc/odroiddac.sh ${ROOTFSMNT}/opt/

  log "Copying ${DEVICENAME} framebuffer init script"
  cp ${PLTDIR}/${DEVICE}/etc/${FRAMEBUFFERINIT} ${ROOTFSMNT}/usr/local/bin/${FRAMEBUFFERINIT}

  log "Copying ${DEVICENAME} inittab"
  cp ${PLTDIR}/${DEVICE}/etc/inittab ${ROOTFSMNT}/etc/

  log "Copying LIRC configuration files for HK stock remote"
  cp "${PLTDIR}/${DEVICE}/etc/lirc/lircd.conf" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICE}/etc/lirc/hardware.conf" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICE}/etc/lirc/lircrc" "${ROOTFSMNT}"

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  dd if=${PLTDIR}/${DEVICE}/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=1 count=442
  dd if=${PLTDIR}/${DEVICE}/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=512 skip=1 seek=1
  dd if=${PLTDIR}/${DEVICE}/uboot/u-boot.bin of=${LOOP_DEV} ${DDUBOOTPARMS}

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  log "device_image_tweaks() not used"
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"
  log "Adding default sound modules"
  cat <<-EOF > /etc/modules
snd_soc_pcm5102
snd_soc_odroid_dac
EOF

  log "Enabling odroiddac.service"
  ln -s /lib/systemd/system/odroiddac.service /etc/systemd/system/multi-user.target.wants/odroiddac.service

  log "Adding framebuffer init script"
  cat <<-EOF > /etc/rc.local
#!/bin/sh -e
/usr/local/bin/c1-init.sh
exit 0
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
