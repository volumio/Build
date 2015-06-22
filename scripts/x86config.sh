#!/bin/bash

# This script will be run in chroot.
echo "Installing grub bootloader"
update-grub
/usr/sbin/grub-install --recheck --no-floppy /dev/sda
