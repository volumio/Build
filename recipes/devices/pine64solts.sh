#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for soPine64 and Pine64LTS devices
# shellcheck source=./recipes/devices/families/pine64.sh
source "${SRC}"/recipes/devices/families/pine64.sh

DEVICENAME="soPine64-Pine64LTS"
DEVICE="pine64solts"
BOOTCONFIG_EXT="uEnv.txt.pine64-so-lts"
UBOOT_MODEL="pine64-so-lts"

