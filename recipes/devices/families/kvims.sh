#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Khadas devices

## WIP, this should be refactored out to a higher level.
# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"

### Device information
# This is useful for multiple devices sharing the same/similar kernel
#DEVICENAME="not set here"
DEVICEFAMILY="khadas"
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEBASE="vims"
DEVICEREPO="https://github.com/volumio/platform-khadas.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=no
KIOSKMODE=no

## Partition info
BOOT_START=16
BOOT_END=80
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("u-boot-tools" "lirc" "fbset" "mc" "abootimg" "bluez-firmware"
  "bluetooth" "bluez" "bluez-tools" "linux-base" "triggerhappy"
)

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {

  trap exit_error INT ERR

  log "Running write_device_files" "ext"

  cp -R "${PLTDIR}/${DEVICEBASE}/boot" "${ROOTFSMNT}"

  log "AML autoscripts not for Volumio"
  rm "${ROOTFSMNT}/boot/aml_autoscript"
  rm "${ROOTFSMNT}/boot/aml_autoscript.cmd"

  log "Retain copies of u-boot files for Volumio Updater"
  cp -r "${PLTDIR}/${DEVICEBASE}/uboot" "${ROOTFSMNT}/boot"
  cp -r "${PLTDIR}/${DEVICEBASE}/uboot-mainline" "${ROOTFSMNT}/boot"

  log "Copying modules & firmware"
  cp -pR "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pR "${PLTDIR}/${DEVICEBASE}/lib/firmware" "${ROOTFSMNT}/lib"

  log "Adding broadcom wlan firmware for vims onboard wlan"
  cp -pR "${PLTDIR}/${DEVICEBASE}/hwpacks/wlan-firmware/brcm/" "${ROOTFSMNT}/lib/firmware"

  log "Adding Meson video firmware"
  cp -pR "${PLTDIR}/${DEVICEBASE}/hwpacks/video-firmware/Amlogic/video" "${ROOTFSMNT}/lib/firmware/"
  cp -pR "${PLTDIR}/${DEVICEBASE}/hwpacks/video-firmware/Amlogic/meson" "${ROOTFSMNT}/lib/firmware/"

  log "Adding Wifi & Bluetooth firmware and helpers"
  cp "${PLTDIR}/${DEVICEBASE}/hwpacks/bluez/hciattach-armhf" "${ROOTFSMNT}/usr/local/bin/hciattach"
  cp "${PLTDIR}/${DEVICEBASE}/hwpacks/bluez/brcm_patchram_plus-armhf" "${ROOTFSMNT}/usr/local/bin/brcm_patchram_plus"
  if [ "${DEVICE}" = kvim3 ] || [ "${DEVICE}" = mp1 ]; then
    log "   For VIM3/MP1: fix issue with AP6359SA and AP6398S using the same chipid and rev"
    mv "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_apsta_ap6398s.bin" "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_apsta.bin"
    mv "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_ap6398s.bin" "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag.bin"
    mv "${ROOTFSMNT}/lib/firmware/brcm/nvram_ap6398s.txt" "${ROOTFSMNT}/lib/firmware/brcm/nvram_ap6359sa.txt"
    mv "${ROOTFSMNT}/lib/firmware/brcm/BCM4359C0_ap6398s.hcd" "${ROOTFSMNT}/lib/firmware/brcm/BCM4359C0.hcd"
  #	cp "${PLTDIR}/${DEVICEBASE}/var/lib/alsa/asound.state.vim3-3l" "${ROOTFSMNT}/var/lib/alsa/asound.state"
  # else
  #	cp "${PLTDIR}/${DEVICEBASE}/var/lib/alsa/asound.state.vim1-2" "${ROOTFSMNT}/var/lib/alsa/asound.state"
  fi

  log "Adding services"
  mkdir -p "${ROOTFSMNT}/lib/systemd/system"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/bluetooth-khadas.service" "${ROOTFSMNT}/lib/systemd/system"
  if [[ "${DEVICE}" != kvim1 ]]; then
    cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/fan.service" "${ROOTFSMNT}/lib/systemd/system"
  fi

  log "Adding usr/local/bin & usr/bin files"
  cp -pR "${PLTDIR}/${DEVICEBASE}/usr" "${ROOTFSMNT}"

  log "Copying rc.local with all prepared ${DEVICE} tweaks"
  cp "${PLTDIR}/${DEVICEBASE}/etc/rc.local" "${ROOTFSMNT}/etc"

  log "Copying triggerhappy configuration"
  cp -pR "${PLTDIR}/${DEVICEBASE}/etc/triggerhappy" "${ROOTFSMNT}/etc"

  #TODO: remove the mp1 restriction when reboot works
  if [[ "${DEVICE}" != mp1 ]]; then
    echo "Copying khadas system halt service"
    cp -pR "${PLTDIR}/${DEVICEBASE}"/etc/systemd "${ROOTFSMNT}/etc"
    cp "${PLTDIR}/${DEVICEBASE}"/opt/poweroff "${ROOTFSMNT}/opt/poweroff"
  else
    #do not use the system-halt.service for mp1 yet
    cp "${PLTDIR}/${DEVICEBASE}/etc/rc.local.mp1" "${ROOTFSMNT}/etc/rc.local"
  fi

}

write_device_bootloader() {

  trap exit_error INT ERR

  log "Running write_device_bootloader u-boot.$BOARD.sd.bin" "ext"

  dd if="${PLTDIR}/${DEVICEBASE}/uboot/u-boot.${KHADASBOARDNAME}.sd.bin" of="${LOOP_DEV}" bs=444 count=1 conv=fsync >/dev/null 2>&1
  dd if="${PLTDIR}/${DEVICEBASE}/uboot/u-boot.${KHADASBOARDNAME}.sd.bin" of="${LOOP_DEV}" bs=512 skip=1 seek=1 conv=fsync >/dev/null 2>&1

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Creating boot parameters from template"
  sed -i "s/#imgpart=UUID=/imgpart=UUID=${UUID_IMG}/g" /boot/env.system.txt
  sed -i "s/#bootpart=UUID=/bootpart=UUID=${UUID_BOOT}/g" /boot/env.system.txt
  sed -i "s/#datapart=UUID=/datapart=UUID=${UUID_DATA}/g" /boot/env.system.txt

  log "Fixing armv8 deprecated instruction emulation, allow dmesg"
  cat <<-EOF >>/etc/sysctl.conf
	abi.cp15_barrier=2
	kernel.dmesg_restrict=0
	EOF

  log "Adding default wifi"
  echo "dhd" >>"/etc/modules"
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  log "Configure triggerhappy"
  echo "DAEMON_OPTS=\"--user root\"" >>"/etc/default/triggerhappy"

  log "Enabling KVIM Bluetooth stack"
  ln -sf "/lib/firmware" "/etc/firmware"
  ln -s "/lib/systemd/system/bluetooth-khadas.service" "/etc/systemd/system/multi-user.target.wants/bluetooth-khadas.service"

  if [[ "${DEVICE}" != kvim1 ]]; then
    ln -s "/lib/systemd/system/fan.service" "/etc/systemd/system/multi-user.target.wants/fan.service"
  fi

  #TODO This can be done outside chroot,
  # removing the need of each image needing u-boot-tools
  # saving some time!
  if [[ -f /boot/volumio.initrd ]]; then
    log "Creating uInitrd from 'volumio.initrd'" "info"
    mkimage -v -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
    rm /boot/volumio.initrd
  fi
}
