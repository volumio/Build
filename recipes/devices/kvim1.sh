#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Khadas VIM1 board
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Import the Khadas vims configuration
# shellcheck source=./recipes/devices/families/kvims.sh
source "${SRC}"/recipes/devices/families/kvims.sh

# Base system
DEVICENAME="Khadas VIM1"
DEVICE="kvim1"
KHADASBOARDNAME="VIM1"

# Called by the image builder for VIM1, overrides default declaration
device_image_tweaks() {

  log "With VIM1: copying khadas system halt service"
  cp -pR "${PLTDIR}/${DEVICEBASE}/etc/systemd" "${ROOTFSMNT}/etc"
  cp "${PLTDIR}/${DEVICEBASE}/opt/poweroff" "${ROOTFSMNT}/opt/poweroff"

}
