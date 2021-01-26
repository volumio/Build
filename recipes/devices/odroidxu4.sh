#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid XU4 device (Community Portings)
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"

### Device information
DEVICENAME="Odroid-XU4"
DEVICE="odroidxu4"
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
BOOT_START=2
BOOT_END=64
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("u-boot-tools")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp ${PLTDIR}/${DEVICEBASE}/boot/boot.ini /mnt/volumio/rootfs/boot
  cp ${PLTDIR}/${DEVICEBASE}/boot/exynos5422-odroidxu4.dtb /mnt/volumio/rootfs/boot
  cp ${PLTDIR}/${DEVICEBASE}/boot/zImage /mnt/volumio/rootfs/boot

  log "Copying modules and firmware and inittab"
  cp -pdR ${PLTDIR}/${DEVICEBASE}/lib/modules /mnt/volumio/rootfs/lib/

  log "Copying modified securetty (oDroid-XU4 console)"
  cp ${PLTDIR}/${DEVICEBASE}/etc/securetty /mnt/volumio/rootfs/etc/

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  log "Copying the bootloader and trustzone software"
  dd iflag=dsync oflag=dsync if=${PLTDIR}/${DEVICEBASE}/uboot/bl1.bin.hardkernel of=${LOOP_DEV} seek=1
  dd iflag=dsync oflag=dsync if=${PLTDIR}/${DEVICEBASE}/uboot/bl2.bin.hardkernel of=${LOOP_DEV} seek=31
  dd iflag=dsync oflag=dsync if=${PLTDIR}/${DEVICEBASE}/uboot/u-boot.bin.hardkernel of=${LOOP_DEV} seek=63
  dd iflag=dsync oflag=dsync if=${PLTDIR}/${DEVICEBASE}/uboot/tzsw.bin.hardkernel of=${LOOP_DEV} seek=719
  echo "Erasing u-boot env"
  dd iflag=dsync oflag=dsync if=/dev/zero of=${LOOP_DEV} seek=1231 count=32 bs=512

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"
  log "Adding XU4 fan control"
  cat <<-EOF >/etc/rc.local
#!/bin/bash
# XU4 Fan Control
# Target temperature: 30°C, 50°C, 70°C
TRIP_POINT_0=30000
TRIP_POINT_1=50000
TRIP_POINT_2=70000

echo \$TRIP_POINT_0 > /sys/devices/virtual/thermal/thermal_zone0/trip_point_0_temp
echo \$TRIP_POINT_0 > /sys/devices/virtual/thermal/thermal_zone1/trip_point_0_temp
echo \$TRIP_POINT_0 > /sys/devices/virtual/thermal/thermal_zone2/trip_point_0_temp
echo \$TRIP_POINT_0 > /sys/devices/virtual/thermal/thermal_zone3/trip_point_0_temp

echo \$TRIP_POINT_1 > /sys/devices/virtual/thermal/thermal_zone0/trip_point_1_temp
echo \$TRIP_POINT_1 > /sys/devices/virtual/thermal/thermal_zone1/trip_point_1_temp
echo \$TRIP_POINT_1 > /sys/devices/virtual/thermal/thermal_zone2/trip_point_1_temp
echo \$TRIP_POINT_1 > /sys/devices/virtual/thermal/thermal_zone3/trip_point_1_temp

echo \$TRIP_POINT_2 > /sys/devices/virtual/thermal/thermal_zone0/trip_point_2_temp
echo \$TRIP_POINT_2 > /sys/devices/virtual/thermal/thermal_zone1/trip_point_2_temp
echo \$TRIP_POINT_2 > /sys/devices/virtual/thermal/thermal_zone2/trip_point_2_temp
echo \$TRIP_POINT_2 > /sys/devices/virtual/thermal/thermal_zone3/trip_point_2_temp
exit 0
EOF
  cat /etc/rc.local
  log "Creating boot.ini from template"
  sed -i "s/%%VOLUMIO-PARAMS%%/imgpart=UUID=${UUID_IMG} bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA}/g" /boot/boot.ini
  cat /boot/boot.ini
  log "Tweaking: disable energy sensor error message"
  cat <<-EOF >>/etc/modprobe.d/blacklist-odroid.conf
blacklist ina231_sensor
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
  if [[ -f /boot/volumio.initrd ]]; then
    log "Creating uInitrd from 'volumio.initrd'" "info"
    mkimage -v -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
    rm /boot/volumio.initrd
  fi
}
