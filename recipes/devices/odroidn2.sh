#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid N2/N2+ devices  (Community Portings)
# shellcheck source=./recipes/devices/families/odroids-newgen.sh
source "${SRC}"/recipes/devices/families/odroids-newgen.sh

# Base system
DEVICENAME="Odroid-N2"
DEVICE="odroidn2"

