#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for basic Pine64 devices  (Community Portings)
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# shellcheck source=./recipes/devices/families/pine64.sh
source "${SRC}"/recipes/devices/families/pine64.sh

### Device information
DEVICENAME="Pine64"
DEVICE="pine64base"
UBOOT_VARIANT="pine64plus"
