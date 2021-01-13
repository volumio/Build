#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Pine64+ devices
# shellcheck source=./recipes/devices/families/pine64.sh
source "${SRC}"/recipes/devices/families/pine64.sh

DEVICENAME="Pine64+"
DEVICE="pine64plus"
BOOTCONFIG_EXT="uEnv.txt.pine64"
UBOOT_MODEL="pine64-plus"

