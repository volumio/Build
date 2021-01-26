#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Khadas VIM3L boards (not to be published because it is OEM configured)
DEVICE_SUPPORT_TYPE="O"   # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"         # First letter (Planned|Test|Maintenance)

# Import the Khadas vims configuration
# shellcheck source=./recipes/devices/families/kvims.sh
source "${SRC}"/recipes/devices/families/kvims.sh

## WIP, this should be refactored out to a higher level.
# Base system
DEVICENAME="Volumio MP1"
DEVICE="mp1"
KHADASBOARDNAME="VIM3L"

# Called by the image builder for mp1 (VIM3L) overrides default declaration
device_image_tweaks() {

  #TODO ===> remove when reboot for MP1 resolved

  log "With VIM3 or MP1 (VIM3L): adding temporary fix for reboot fix "
  mv "${ROOTFSMNT}/sbin/ifconfig" "${ROOTFSMNT}/opt"
  mv "${ROOTFSMNT}/bin/ip" "${ROOTFSMNT}/opt"
  cp "${PLTDIR}/${DEVICEBASE}/opt/ifconfig.fix" "${ROOTFSMNT}/sbin/ifconfig"
  cp "${PLTDIR}/${DEVICEBASE}/opt/ip.fix" "${ROOTFSMNT}/bin/ip"

  log "With VIM3 or MP1 (VIM3L): fix issue with AP6359SA and AP6398S using the same chipid and rev"
  mv "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_apsta_ap6398s.bin" "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_apsta.bin"
  mv "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_ap6398s.bin" "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag.bin"
  mv "${ROOTFSMNT}/lib/firmware/brcm/nvram_ap6398s.txt" "${ROOTFSMNT}/lib/firmware/brcm/nvram_ap6359sa.txt"
  mv "${ROOTFSMNT}/lib/firmware/brcm/BCM4359C0_ap6398s.hcd" "${ROOTFSMNT}/lib/firmware/brcm/BCM4359C0.hcd"

  log "With VIM2/ VIM3/ MP1(VIM3L): adding fan services"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/fan.service" "${ROOTFSMNT}/lib/systemd/system"

#TODO: remove the mp1 restriction when reboot works
#do not use the system-halt.service for mp1 yet
  cp "${PLTDIR}/${DEVICEBASE}/etc/rc.local.mp1" "${ROOTFSMNT}/etc/rc.local"

}

