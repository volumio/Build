#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for FriendlyElec Nanopi Neo3  (Community Portings)
DEVICE_SUPPORT_TYPE="C,O" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"         # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"

### Device information
DEVICENAME="Nanopi Neo3"
DEVICE="nanopineo3"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="nanopi"
DEVICEBASE="nanopi-neo3"
# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes

## Partition info
BOOT_START=20
BOOT_END=84
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=no         # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("u-boot-tools" "device-tree-compiler")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICEBASE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/firmware" "${ROOTFSMNT}/lib"
}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICEBASE}/u-boot/idbloader.bin" of="${LOOP_DEV}" seek=64 conv=notrunc
  dd if="${PLTDIR}/${DEVICEBASE}/u-boot/uboot.img" of="${LOOP_DEV}" seek=16384 conv=notrunc
  dd if="${PLTDIR}/${DEVICEBASE}/u-boot/trust.bin" of="${LOOP_DEV}" seek=24576 conv=notrunc
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

  log "Creating boot config"
  cat <<-EOF >/boot/extlinux/extlinux.conf
label kernel-5.4
    kernel /Image
    fdt /rk3328-nanopi-neo3-rev02.dtb
    initrd /uInitrd
    append  earlycon=uart8250,mmio32,0xff130000 console=ttyS2,1500000 console=tty1 imgpart=/dev/mmcblk0p2 imgfile=/volumio_current.sqsh hwdevice=nanopineo3 bootdev=mmcblk0
EOF

  log "Changing to 'modules=list' to limit uInitrd size"
  sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf

  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >/etc/sysctl.conf
abi.cp15_barrier=2
EOF

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  log "Creating uInitrd from 'volumio.initrd'" "info"
  #TODO This can be done outside chroot,
  # removing the need of each image needing u-boot-tools
  # saving some time!
  mkimage -v -A arm64 -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
  log "Removing unnecessary /boot files"
  rm /boot/volumio.initrd
}
