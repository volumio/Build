#!/bin/bash


# This script will be run in chroot.
echo "Initialising.."
. init.sh

echo "Creating node/ nodejs symlinks to stay compatible with the armv6/v7 platforms"
ln -s /usr/bin/node /usr/local/bin/node
ln -s /usr/bin/nodejs /usr/local/bin/nodejs

#TODO temporary mpd.conf fix and s/pdif unmute, to be moved to a patch file...
sed -i "s/hw:0,0/hw:0,1/g" /etc/mpd.conf

# Make grub boot menu transparent
sed -i "s/menu_color_normal=cyan\/blue/menu_color_normal=white\/black/g" /etc/grub.d/05_debian_theme

#echo "Create grub config folder"
mkdir -p /boot/grub

echo "Applying Grub Configuration"
grub-mkconfig -o /boot/grub/grub.cfg

echo "Installing grub bootloader"
update-grub
grub-install --boot-directory=/boot $LOOP_DEV

echo "Fixing root and boot device in case loop device was used"
rpl -ivRd -x'.cfg' `echo root="$( echo ${LOOP_PART})"` `echo root=UUID="$( echo ${UUID})"` /boot/grub 

echo "Editing fstab to use UUID"
sed -i "s/\/dev\/sda1/`echo UUID="$( echo ${UUID})"`/g" /etc/fstab

#echo "Updating initramfs to avound fsck errors, also needs busybox"
VERSION="$(ls -t /lib/modules | cat | head -n2)"
update-initramfs -u -k $VERSION

echo "Bootloader configuration complete"
