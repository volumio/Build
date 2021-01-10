#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Volumio Motivo device

## WIP, this should be refactored out to a higher level.
# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"

### Device information
DEVICENAME="Motivo"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="motivo"
DEVICE="motivo"
DEVICEREPO="https://github.com/volumio/platform-motivo.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=no
KIOSKMODE=no

## Partition info
BOOT_START=21
BOOT_END=84
IMAGE_END=3200
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=(
  # Base for initramfs
  "overlay" "squashfs" "nls_cp437"
  # Touchscreen panels
  "panel-feiyang-fy07024di26a30d" "panel-motivo-mt1280800"
  # lima
  "lima"
)

# Packages that will be installed
PACKAGES=(
  # makeimage
  "u-boot-tools"
  # CD support
  "libcdio-dev" "libcdparanoia-dev"
  # Bluetooth support
  "bluez-firmware" "bluetooth" "bluez" "bluez-tools"
)

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  log "Copy boot files"
  cp -R "${PLTDIR}/${DEVICE}/boot" "${ROOTFSMNT}"

  log "Compile the boot script"
  mkimage -C none -A arm -T script -d "${PLTDIR}/${DEVICE}/boot/boot.cmd" "${ROOTFSMNT}/boot/boot.scr"

  log "Kernel modules and firmware"
  cp -dR "${PLTDIR}/${DEVICE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -dR "${PLTDIR}/${DEVICE}/firmware" "${ROOTFSMNT}/lib"

  log "Confguring ALSA with sane defaults"
  cp -R "${PLTDIR}/${DEVICE}/var/lib/alsa" "${ROOTFSMNT}/var/lib"

  log "Copy the tslib package and config"
  cp "${PLTDIR}/${DEVICE}/extras/libts-bin_1.19-1_armhf.deb" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICE}/extras/libts0_1.19-1_armhf.deb" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICE}/extras/ts.conf" "${ROOTFSMNT}/etc"
  cp "${PLTDIR}/${DEVICE}/extras/pointercal" "${ROOTFSMNT}/etc"

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICE}/u-boot/sunxi-spl.bin" of="${LOOP_DEV}" conv=fsync bs=8k seek=1
  dd if="${PLTDIR}/${DEVICE}/u-boot/u-boot.itb" of="${LOOP_DEV}" conv=fsync bs=8k seek=5
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Modify uEnv.txt template"
  sed -i "s/%%BOOT-SD%%/rebootmode=file bootdev=mmcblk0 bootpart=\/dev\/mmcblk0p1 imgpart=\/dev\/mmcblk0p2 datapart=\/dev\/mmcblk0p3/g" /boot/uEnv.txt
  sed -i "s/%%BOOT-EMMC%%/rebootmode=file bootdev=mmcblk2 bootpart=\/dev\/mmcblk2p1 imgpart=\/dev\/mmcblk2p2 datapart=\/dev\/mmcblk2p3/g" /boot/uEnv.txt

  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >>/etc/sysctl.conf
	abi.cp15_barrier=2
	EOF

  log "Enabling Bluetooth Adapter auto-poweron"
  cat <<-EOF >/etc/bluetooth/main.conf
	[Policy]
	AutoEnable=true
	EOF

  log "Installing tslib for ts calibration purposes"
  dpkg -i -f noninteractive /libts0_1.19-1_armhf.deb
  dpkg -i /libts-bin_1.19-1_armhf.deb

  log "Cleanup unused .debs"
  rm /libts0_1.19-1_armhf.deb
  rm /libts-bin_1.19-1_armhf.deb

  log "Add fbturbo to increase X performances"
  wget http://repo.volumio.org/Volumio2/motivo/x-packages/libump_3.0-0sunxi1_armhf.deb
  dpkg -i libump_3.0-0sunxi1_armhf.deb
  wget http://repo.volumio.org/Volumio2/motivo/x-packages/xf86-video-fbturbo_1.00-1_armhf.deb
  dpkg -i xf86-video-fbturbo_1.00-1_armhf.deb
  rm xf86-video-fbturbo_1.00-1_armhf.deb

  log "Adding motivo-specific counter-clockwise screen rotation"
  cat <<-EOF >/etc/X11/xorg.conf
	Section "Device"
	  Identifier "LCD"
	  Driver "fbturbo"
	  Option "fbdev" "/dev/fb0"
	  Option "Rotate" "CCW"
	  Option "SwapbuffersWait" "true"
	  Option "HWCursor" "false"
	  Option "RandRRotation" "on"
	EndSection
	
	Section "InputClass"
	  Identifier   "calibration"
	  MatchProduct "Goodix Capacitive TouchScreen"
	  Option       "Calibration" "0 1280 0 800"
	EndSection
	EOF

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
