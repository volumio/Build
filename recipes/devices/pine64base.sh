#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for basic Pine64 devices  (Community Portings)

# shellcheck source=./recipes/devices/families/pine64.sh
source "${SRC}"/recipes/devices/families/pine64.sh

DEVICENAME="Pine64"
DEVICE="pine64"
UBOOT_VARIANT="pine64plus"

