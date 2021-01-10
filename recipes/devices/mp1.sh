#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Khadas VIM boards
# Import the Khadas vims configuration
# shellcheck source=./recipes/devices/families/kvims.sh
source "${SRC}"/recipes/devices/families/kvims.sh

## WIP, this should be refactored out to a higher level.
# Base system
DEVICENAME="Volumio MP1"
DEVICE="mp1"
KHADASBOARDNAME="VIM3L"

# Test: would be called by the image builder for any customisation, overrides default declaration
#device_image_tweaks() {
#  log "THIS DOES A SUCCESSFULL OVERRIDE OF KVIMS VERSION OF device_imge_tweaks()"
#}

