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
# to a string which we can replace after creating the grub config file
sed -i "s/LINUX_ROOT_DEVICE=\${GRUB_DEVICE}/LINUX_ROOT_DEVICE=imgpart=%%IMGPART%% /g" /etc/grub.d/10_linux
sed -i "s/LINUX_ROOT_DEVICE=UUID=\${GRUB_DEVICE_UUID}/LINUX_ROOT_DEVICE=imgpart=%%IMGPART%% /g" /etc/grub.d/10_linux

#echo "Creating grub config folder"
mkdir -p /boot/grub

echo "Applying Grub Configuration"
grub-mkconfig -o /boot/grub/grub.cfg
chmod +w boot/grub/grub.cfg

echo "Inserting root and boot partition UUID (building the boot cmdline used in initramfs)"
# Opting for finding partitions by-UUID
sed -i "s/root=imgpart=%%IMGPART%%/`echo imgpart=UUID="$( echo ${UUID_IMG})"`/g" /boot/grub/grub.cfg
sed -i "s/bootpart=%%BOOTPART%%/`echo bootpart=UUID="$( echo ${UUID_BOOT})"`/g" /boot/grub/grub.cfg

echo "Creating and installing UEFI Bootloader" 
grub-mkstandalone --compress=gz -O x86_64-efi -o /boot/efi/EFI/debian/grubx64.efi -d /usr/lib/grub/x86_64-efi --modules="part_gpt part_msdos" --fonts="unicode" --locales="en@quot" --themes="" /boot/grub/grub.cfg 
echo "Copying to Fallback Bootloader"
cp -P /boot/efi/EFI/debian/grubx64.efi /boot/efi/BOOT/BOOTX64.EFI

#TODO: we also need to create an i386-efi bootloader to cover the (rare) 32bit UEFI machines
echo "TODO: Adding Bootloader for 32bit uefi"
echo "Adding Legacy Bootloader"
grub-install --target=i386-pc --boot-directory=/boot $LOOP_DEV


echo "Editing fstab to use UUID"
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
