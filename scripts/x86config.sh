#!/bin/bash

# This script will be run in chroot.
echo "Create grub config folder"
mkdir -p /boot/grub

echo "Applying Grub Configuration"
grub-mkconfig -o /boot/grub/grub.cfg

echo "Installing grub bootloader"
update-grub
grub-install --boot-directory=/boot /dev/loop0

echo "Fixing Grub Boot device"
rpl -ivRd -x'.cfg' 'root=/dev/mapper/loop0p1' 'root=/dev/sda1' /boot/grub 

echo "Bootloader configuration complete"
