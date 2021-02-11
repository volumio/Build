#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Rock64 (pine64.org) devices (Community Portings)
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm64"

### Device information
DEVICENAME="Rock64"
DEVICE="rock64"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="rock64"
# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=yes
VOLINITUPDATER=yes

## Partition info
BOOT_START=20
BOOT_END=84
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("device-tree-compiler" "liblircclient0" "lirc")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICEBASE}/boot" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICEBASE}/boot/dtb/rk3328-rock64.dtb" "${ROOTFSMNT}/boot"
  rm -r "${ROOTFSMNT}/boot/dtb"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/firmware" "${ROOTFSMNT}/lib"

  log "Adding missing alsa dependencies and dt-overlay tool"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/usr" "${ROOTFSMNT}"

  log "Adding temporary fixes to Rock64 board"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/etc" "${ROOTFSMNT}"

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICEBASE}/u-boot/idbloader.img" of="${LOOP_DEV}" seek=64 conv=notrunc
  dd if="${PLTDIR}/${DEVICEBASE}/u-boot/uboot.img" of="${LOOP_DEV}" seek=16384 conv=notrunc
  dd if="${PLTDIR}/${DEVICEBASE}/u-boot/trust.img" of="${LOOP_DEV}" seek=24576 conv=notrunc
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
label kernel-4.4
    kernel /Image
    fdt /rk3328-rock64.dtb
    initrd /uInitrd
    append  earlycon=uart8250,mmio32,0xff130000 swiotlb=1 kpti=0 console=tty1 console=ttyS2,1500000n8 imgpart=UUID=${UUID_IMG} imgfile=/volumio_current.sqsh hwdevice=Rock64 bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA} bootconfig=/extlinux/extlinux.conf loglevel=7
EOF

  log "Changing to 'modules=list' to limit uInitrd size"
  sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf

  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >>/etc/sysctl.conf
abi.cp15_barrier=2
EOF
  chmod +x /usr/local/sbin/enable_dtoverlay
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  # log "Running device_chroot_tweaks_post" "ext"
  :
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
