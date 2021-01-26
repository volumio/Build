#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Khadas VIM3 board
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Import the Khadas vims configuration
# shellcheck source=./recipes/devices/families/kvims.sh
source "${SRC}"/recipes/devices/families/kvims.sh

# Base system
DEVICENAME="Khadas VIM3"
DEVICE="kvim3"
KHADASBOARDNAME="VIM3"

# Called by the image builder for VIM3, overrides default declaration
device_image_tweaks() {

  log "With VIM3 or MP1 (VIM3L): fix issue with AP6359SA and AP6398S using the same chipid and rev"
  mv "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_apsta_ap6398s.bin" "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_apsta.bin"
  mv "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_ap6398s.bin" "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag.bin"
  mv "${ROOTFSMNT}/lib/firmware/brcm/nvram_ap6398s.txt" "${ROOTFSMNT}/lib/firmware/brcm/nvram_ap6359sa.txt"
  mv "${ROOTFSMNT}/lib/firmware/brcm/BCM4359C0_ap6398s.hcd" "${ROOTFSMNT}/lib/firmware/brcm/BCM4359C0.hcd"

  log "With VIM2/ VIM3: Copying khadas system halt and fan service"
  cp -pR "${PLTDIR}/${DEVICEBASE}/etc/systemd" "${ROOTFSMNT}/etc"
  cp "${PLTDIR}/${DEVICEBASE}/opt/poweroff" "${ROOTFSMNT}/opt/poweroff"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/fan.service" "${ROOTFSMNT}/lib/systemd/system"

}
