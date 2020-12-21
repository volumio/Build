#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Asus Tinerboard device
#TODO handle single base with multiple devices

## WIP, this should be refactored out to a higher level.
# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"

### Device information
DEVICENAME="Asus Tinkerboard"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEBASE="tinkerboard"
DEVICEREPO="https://github.com/volumio/platform-asus.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=no
KIOSKMODE=yes

## Partition info
BOOT_START=1
BOOT_END=64
BOOT_TYPE=msdos          # msdos or gpt
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "overlayfs" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("u-boot-tools" "plymouth" "plymouth-themes")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/firmware" "${ROOTFSMNT}/lib"

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICE}/u-boot/u-boot.img" of="${LOOP_DEV}" seek=64 conv=notrunc

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"
  log "Update fstab with UUIDs"
  sed -i "s_/dev/mmcblk0p1_UUID=${UUID_BOOT}_" /etc/fstab
  # Grab latest kernel version
  mapfile -t kernel_versions < <(ls -t /lib/modules | sort)
  log "Creating extlinux.conf for Kernel -- ${kernel_versions[0]}"
  cat <<-EOF >/boot/extlinux/extlinux.conf
label $(awk -F . '{print "kernel-"$1"."$2}' <<<"${kernel_versions[0]}")
  kernel /zImage
  fdt /dtb/rk3288-miniarm.dtb
  initrd /uInitrd
  append  earlyprintk splash console=tty1 console=ttyS3,115200n8 rw init=/sbin/init imgpart=UUID=${UUID_IMG} imgfile=/volumio_current.sqsh bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA} bootconfig=/extlinux/extlinux.conf logo.nologo vt.global_cursor_default=0 loglevel=8
EOF
  cat <<-EOF >/usr/local/bin/tinker-init.sh
#!/bin/sh
echo 2 > /proc/irq/45/smp_affinity
EOF
  chmod +x /usr/local/bin/tinker-init.sh

  log "Installing Tinkerboard Bluetooth Utils and Firmware"
  wget http://repo.volumio.org/Volumio2/Firmwares/rtl_bt_tinkerboard.tar.gz
  tar xf rtl_bt_tinkerboard.tar.gz -C /
  rm rtl_bt_tinkerboard.tar.gz
  systemctl enable tinkerbt.service

  log "Installing updated Realtek firmwares"
  wget http://repo.volumio.org/Volumio2/Firmwares/firmware-realtek_20190114-2_all.deb
  dpkg -i firmware-realtek_20190114-2_all.deb
  rm firmware-realtek_20190114-2_all.deb

  log "Configuring boot splash"
  plymouth-set-default-theme volumio

  log "Switching iptables"
  update-alternatives --set iptables /usr/sbin/iptables-legacy

  # echo "Installing Kiosk"
  # sh /install-kiosk.sh

  # echo "Kiosk installed"
  # rm /install-kiosk.sh
  # Thsis needs to be MOST for buster
  #log "Changing to 'modules=dep'"
  #sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  #TODO This can be done outside chroot,
  # removing the need of each image needing u-boot-tools
  # saving some time!
  if [[ -f /boot/volumio.initrd ]]; then
    log "Creating uInitrd from 'volumio.initrd'" "info"
    mkimage -v -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
    rm /boot/volumio.initrd
  fi
}
