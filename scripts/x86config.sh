#!/bin/bash

. init.sh

# This script will be run in chroot.
echo "Create grub config folder"
mkdir -p /boot/grub

echo "Applying Grub Configuration"
grub-mkconfig -o /boot/grub/grub.cfg

echo "Installing grub bootloader"
update-grub
grub-install --boot-directory=/boot $LOOP_DEV

echo "Fixing Grub Boot device"
rpl -ivRd -x'.cfg' `echo root="$( echo ${LOOP_PART})"` 'root=/dev/sda1' /boot/grub 

echo "Bootloader configuration complete"
