#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for soPine64 and Pine64LTS devices  (Community Portings)
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# shellcheck source=./recipes/devices/families/pine64.sh
source "${SRC}"/recipes/devices/families/pine64.sh

### Device information
DEVICENAME="soPine64-Pine64LTS"
DEVICE="pine64solts"
UBOOT_VARIANT="pine64solts"
