#!/usr/bin/env bash
# shellcheck disable=SC2034

### Setup for x86_amd64 devices
DEVICE_SUPPORT_TYPE="S" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Import the x86 base family configuration
# shellcheck source=./recipes/devices/families/x86.sh
source "${SRC}"/recipes/devices/families/x86.sh

# Base system
ARCH="amd64"
BUILD="x64"
DEVICENAME="x86_64"
