#!/usr/bin/env bash
# shellcheck disable=SC2034

### Setup for x86_amd64 devices
# Import the x86_i368 configuration
# shellcheck source=./recipes/devices/x86_i386.sh
source "${SRC}"/recipes/devices/x86_i386.sh

# And only adjust the bits that are different
ARCH="amd64"
BUILD="x64"
DEVICENAME="x64"
