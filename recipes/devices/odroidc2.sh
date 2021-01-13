#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid C2 device
# shellcheck source=./recipes/devices/families/odroids-earlygen.sh
source "${SRC}"/recipes/devices/families/odroids-earlygen.sh

DEVICENAME="Odroid-C2"
DEVICE="odroidc2"
KERNELFILENAME="Image"
DTBFILENAME="meson64_odroidc2.dtb"
FRAMEBUFFERINIT="C2_init.sh"
DDUBOOTPARMS="conv=fsync bs=512 seek=97"
UINITRD_ARCH="arm64"
