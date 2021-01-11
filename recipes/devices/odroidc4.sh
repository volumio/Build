#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid C4 device
# shellcheck source=./recipes/devices/families/odroids-newgen.sh
source "${SRC}"/recipes/devices/families/odroids-newgen.sh

# Base system
DEVICENAME="Odroid-C4"
DEVICE="odroidc4"

