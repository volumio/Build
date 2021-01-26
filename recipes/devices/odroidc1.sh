#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid C1 device  (Community Portings)
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# shellcheck source=./recipes/devices/families/odroids-earlygen.sh
source "${SRC}"/recipes/devices/families/odroids-earlygen.sh

### Device information
DEVICENAME="Odroid-C1"
DEVICE="odroidc1"
KERNELFILENAME="uImage"
DTBFILENAME="meson8b_odroidc.dtb"
FRAMEBUFFERINIT="C1_init.sh"
DDUBOOTPARMS="seek=64"
UINITRD_ARCH="arm"
