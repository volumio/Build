#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Khadas VIM2 board
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Import the Khadas vims configuration
# shellcheck source=./recipes/devices/families/kvims.sh
source "${SRC}"/recipes/devices/families/kvims.sh

# Base system
DEVICENAME="Khadas VIM2"
DEVICE="kvim2"
KHADASBOARDNAME="VIM2"

# Called by the image builder for VIM2, overrides default declaration
device_image_tweaks() {

  log "With VIM2/ VIM3: Copying khadas system halt and fan service"
  cp -pR "${PLTDIR}/${DEVICEBASE}/etc/systemd" "${ROOTFSMNT}/etc"
  cp "${PLTDIR}/${DEVICEBASE}/opt/poweroff" "${ROOTFSMNT}/opt/poweroff"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/fan.service" "${ROOTFSMNT}/lib/systemd/system"

  log "With VIM2/ VIM3/ MP1 (VIM3L): adding fan services"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/fan.service" "${ROOTFSMNT}/lib/systemd/system"

}
