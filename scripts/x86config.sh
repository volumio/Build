#!/bin/bash

# This script will be run in chroot.
echo "Installing grub bootloader"
update-grub
grub-install --boot-directory=$TMPDIR/boot /dev/loop0
