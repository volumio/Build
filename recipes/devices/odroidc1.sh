#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid C1 device
# shellcheck source=./recipes/devices/families/odroids-earlygen.sh
source "${SRC}"/recipes/devices/families/odroids-earlygen.sh

DEVICENAME="Odroid-C1"
DEVICE="odroidc1"
KERNELFILENAME="uImage"
DTBFILENAME="meson8b_odroidc.dtb"
FRAMEBUFFERINIT="C1_init.sh"
DDUBOOTPARMS="seek=64"
UINITRD_ARCH="arm"
FLAGS_EXT4=("-O" "^metadata_csum,^64bit") # Disable ext4 metadata checksums
