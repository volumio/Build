#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid N2/N2+ devices  (Community Portings)
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# shellcheck source=./recipes/devices/families/odroids-newgen.sh
source "${SRC}"/recipes/devices/families/odroids-newgen.sh

### Device information
DEVICENAME="Odroid-N2"
DEVICE="odroidn2"
