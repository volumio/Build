#!/bin/bash


# This script will be run in chroot.
echo "Initialising.."
. init.sh

echo "Creating symlinks to stay compatible with the armv6/v7 platforms"
ln -s /usr/bin/node /usr/local/bin/node
ln -s /usr/bin/nodejs /usr/local/bin/nodejs

#TODO temporary mpd.conf fix and s/pdif unmute, to be moved to a patch file...
sed -i "s/hw:0,0/hw:0,1/g" /etc/mpd.conf
 
echo "Create grub config folder"
mkdir -p /boot/grub

echo "Applying Grub Configuration"
grub-mkconfig -o /boot/grub/grub.cfg

echo "Installing grub bootloader"
update-grub
grub-install --boot-directory=/boot $LOOP_DEV

echo "Fixing Grub Boot device"
rpl -ivRd -x'.cfg' `echo root="$( echo ${LOOP_PART})"` `echo root=UUID="$( echo ${UUID})"` /boot/grub 

echo "Editing fstab to use UUID"
sed -i "s/\/dev\/sda1/`echo UUID="$( echo ${UUID})"`/g" /etc/fstab

echo "Updating initramfs to avound fsck errors, also needs busybox"
apt-get update
apt-get -y install busybox
VERSION="$(ls -t /lib/modules | cat | head -n2)"
update-initramfs -u -k $VERSION

echo "Bootloader configuration complete"
