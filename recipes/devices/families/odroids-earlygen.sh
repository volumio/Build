#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid C1/C2 device (Community Portings)

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
VOLINITUPDATER=yes
KIOSKMODE=no

## Partition info
BOOT_START=1
BOOT_END=64
BOOT_TYPE=msdos                           # msdos or gpt
BOOT_USE_UUID=no                          # Add UUID to fstab
INIT_TYPE="init"                          # init.{x86/nextarm/nextarm_tvbox}
FLAGS_EXT4=("-O" "^metadata_csum,^64bit") # Disable ext4 metadata checksums

# Modules that will be added to intramsfs
MODULES=("overlayfs" "overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("liblircclient0" "lirc" "fbset")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  log "Copying ${DEVICENAME} boot files"
  cp ${PLTDIR}/${DEVICEBASE}/boot/boot.ini* ${ROOTFSMNT}/boot
  cp ${PLTDIR}/${DEVICEBASE}/boot/${DTBFILENAME} ${ROOTFSMNT}/boot
  cp ${PLTDIR}/${DEVICEBASE}/boot/${KERNELFILENAME} ${ROOTFSMNT}/boot

  log "Copying ${DEVICENAME} modules and firmware"
  cp -pdR ${PLTDIR}/${DEVICEBASE}/lib/modules ${ROOTFSMNT}/lib/
  cp -pdR ${PLTDIR}/${DEVICEBASE}/lib/firmware ${ROOTFSMNT}/lib/

  log "Copying ${DEVICENAME} DAC detection service"
  cp ${PLTDIR}/${DEVICEBASE}/etc/odroiddac.service ${ROOTFSMNT}/lib/systemd/system/
  cp ${PLTDIR}/${DEVICEBASE}/etc/odroiddac.sh ${ROOTFSMNT}/opt/

  log "Copying ${DEVICENAME} framebuffer init script"
  cp ${PLTDIR}/${DEVICEBASE}/etc/${FRAMEBUFFERINIT} ${ROOTFSMNT}/usr/local/bin/c_init.sh

  log "Copying ${DEVICENAME} inittab"
  cp ${PLTDIR}/${DEVICEBASE}/etc/inittab ${ROOTFSMNT}/etc/

  #Temp Solution until init refactoring
  log "Copy early odroid init script, bypassing overlayfs syntax issues"
  cp "${PLTDIR}/${DEVICEBASE}/etc/init.odroid-earlygen" "${ROOTFSMNT}"

  log "Copying LIRC configuration files for HK stock remote"
  cp "${PLTDIR}/${DEVICEBASE}/etc/lirc/lircd.conf" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICEBASE}/etc/lirc/hardware.conf" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICEBASE}/etc/lirc/lircrc" "${ROOTFSMNT}"

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  dd if=${PLTDIR}/${DEVICEBASE}/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=1 count=442
  dd if=${PLTDIR}/${DEVICEBASE}/uboot/bl1.bin.hardkernel of=${LOOP_DEV} bs=512 skip=1 seek=1
  dd if=${PLTDIR}/${DEVICEBASE}/uboot/u-boot.bin of=${LOOP_DEV} ${DDUBOOTPARMS}

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  log "device_image_tweaks() not used"
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"
  log "Adding default sound modules"
  cat <<-EOF >/etc/modules
snd_soc_pcm5102
snd_soc_odroid_dac
EOF

  log "Enabling odroiddac.service"
  ln -s /lib/systemd/system/odroiddac.service /etc/systemd/system/multi-user.target.wants/odroiddac.service

  log "Adding framebuffer init script"
  cat <<-EOF >/etc/rc.local
#!/bin/sh -e
/usr/local/bin/c_init.sh
exit 0
EOF

  log "Changing initramfs module config to 'modules=list' to limit uInitrd size" "cfg"
  sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf

  log "Copy initramfs init script into place"
  mv init.odroid-earlygen /root/init

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  log "Configuring HK stock remote"
  cp lircd.conf /etc/lirc
  cp hardware.conf /etc/lirc
  cp lircrc /etc/lirc
  rm lircd.conf hardware.conf lircrc

}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
  log "Running device_image_tweaks_post" "ext"
  log "Creating uInitrd from 'volumio.initrd'" "info"
  if [[ -f "${ROOTFSMNT}"/boot/volumio.initrd ]]; then
    mkimage -v -A "${UINITRD_ARCH}" -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d "${ROOTFSMNT}"/boot/volumio.initrd "${ROOTFSMNT}"/boot/uInitrd
    rm "${ROOTFSMNT}"/boot/volumio.initrd
  fi
}
