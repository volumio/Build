#!/bin/bash

# This script will be run in chroot.
echo "Initializing.."
. init.sh

echo "Installing the kernel and creating initramfs"
# Kernel version not known yet
# Not brilliant, but safe enough as x86.sh only copied one image and one firmware package version
dpkg -i linux-image-*_i386.deb
dpkg -i linux-firmware-*_i386.deb

echo "Creating node/ nodejs symlinks to stay compatible with the armv6/v7 platforms"
ln -s /usr/bin/node /usr/local/bin/node
ln -s /usr/bin/nodejs /usr/local/bin/nodejs

echo "Blacklisting PC speaker"
echo "blacklist snd_pcsp" >> /etc/modprobe.d/blacklist.conf


# Make grub boot menu transparent
sed -i "s/menu_color_normal=cyan\/blue/menu_color_normal=white\/black/g" /etc/grub.d/05_debian_theme
sed -i "s/menu_color_highlight=white\/blue/menu_color_highlight=green\/dark-gray/g" /etc/grub.d/05_debian_theme
# replace the initrd string in the template
sed -i "s/initrd=\"\$i\"/initrd=\"volumio.initrd\"/g" /etc/grub.d/10_linux

#replace both LINUX_ROOT_DEVICE and LINUX_ROOT_DEVICE=UUID= in the template 
# to a string which we can replace after instaling grub
sed -i "s/LINUX_ROOT_DEVICE=\${GRUB_DEVICE}/LINUX_ROOT_DEVICE=imgpart=%%IMGPART%% /g" /etc/grub.d/10_linux
sed -i "s/LINUX_ROOT_DEVICE=UUID=\${GRUB_DEVICE_UUID}/LINUX_ROOT_DEVICE=imgpart=%%IMGPART%% /g" /etc/grub.d/10_linux

#echo "Creating grub config folder"
mkdir -p /boot/grub

#TODO: check if it is not better just to have our own Volumio standard grub.conf
#(so we can forget all the grub customizing above just do the editing down below
echo "Applying Grub Configuration"
grub-mkconfig -o /boot/grub/grub.cfg

echo "Installing grub bootloader"
grub-install --boot-directory=/boot $LOOP_DEV

echo $UUID_BOOT
echo $UUID_IMG

echo "Fixing root and boot device in case loop device was used"
# Opting for finding partitions by-UUID
sed -i "s/root=imgpart=%%IMGPART%%/`echo imgpart=UUID="$( echo ${UUID_IMG})"`/g" /boot/grub/grub.cfg
sed -i "s/bootpart=%%BOOTPART%%/`echo bootpart=UUID="$( echo ${UUID_BOOT})"`/g" /boot/grub/grub.cfg

echo "Editing fstab to use UUID"
#TODO: make an fstab template too?
sed -i "s/%%BOOTPART%%/`echo UUID="$( echo ${UUID_BOOT})"`/g" /etc/fstab

echo "Creating initramfs"
echo "Adding custom modules"
echo "overlay" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules
echo "usbcore" >> /etc/initramfs-tools/modules
echo "usb_common" >> /etc/initramfs-tools/modules
echo "uhci_hcd" >> /etc/initramfs-tools/modules
echo "ehci_pci" >> /etc/initramfs-tools/modules
echo "ehci_hcd" >> /etc/initramfs-tools/modules
echo "xhci_hcd" >> /etc/initramfs-tools/modules
echo "usbhid" >> /etc/initramfs-tools/modules
echo "hid_cherry" >> /etc/initramfs-tools/modules
echo "hid_generic" >> /etc/initramfs-tools/modules
echo "hid" >> /etc/initramfs-tools/modules
echo "nls_cp437" >> /etc/initramfs-tools/modules
echo "nls_utf8" >> /etc/initramfs-tools/modules
echo "vfat" >> /etc/initramfs-tools/modules

echo "Copying volumio initramfs updater"
cd /root/
mv volumio-init-updater /usr/local/sbin

echo "Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp

echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart

echo "Bootloader configuration and initrd.img complete"
