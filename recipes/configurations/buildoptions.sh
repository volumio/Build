#!/usr/bin/env bash
# location for configuration(s) for build system flags

# Working directories
export BUILD_OUTPUT_DIR=${BUILD_OUTPUT_DIR:-./build}     # dir for rootfs creation
export MOUNT_DIR=${MOUNT_DIR:-/mnt/volumio}              # dir where rootfs is mounted to create final image
export LOCAL_PKG_DIR=${LOCAL_PKG_DIR:-./customPkgs}      # location of locally built packages
export LOCAL_MODULES_DIR=${LOCAL_MODULES_DIR:-./modules} # same for node_modules tarball
export OUTPUT_DIR=${OUTPUT_DIR:-./}                      # Dir where final image is created

# Artifacts copied into rootfs
export UPDATE_VOLUMIO=${UPDATE_VOLUMIO:-no}                 # Check BE/FE repos for latest commit when building image from rootfs
export USE_LOCAL_NODE_MODULES=${USE_LOCAL_NODE_MODULES:-no} # Use node_modules tarball from LOCAL_MODULES_DIR
export USE_LOCAL_PACKAGES=${USE_LOCAL_PACKAGES:-no}         # Use packages in from LOCAL_PKG_DIR

# Image creation options
export CLEAN_IMAGE_FILE=${CLEAN_IMAGE_FILE:-yes} # Delete kernel,squashfs, and image
export DEBUG_IMAGE=${DEBUG_IMAGE:-no}            # Enable debugging (verbose boot, serial console, etc)

# Pi specific
export USE_NODE_ARMV6=${USE_NODE_ARMV6:-yes}              # Use armv6 based Nodejs for all Pis
export RPI_USE_LATEST_KERNEL=${RPI_USE_LATEST_KERNEL:-no} # Fetch latest Pi kernel

# Misc
export USE_BUILD_TESTS=${USE_BUILD_TESTS:-no} # Run some simple build framework tests for debugging
export APT_CACHE=${APT_CACHE:-}               # URL of local cache of the Debian mirror
