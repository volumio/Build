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
ln -s /usr/bin/nodejs /usr/local/bin/nodejs

echo "Blacklisting PC speaker"
echo "blacklist snd_pcsp" >> /etc/modprobe.d/blacklist.conf

echo "Installing Syslinux Legacy BIOS"
syslinux -v
syslinux "${BOOT_PART}" 

echo "  Getting the current kernel filename"
KRNL=`ls -l /boot |grep vmlinuz | awk '{print $9}'`
echo "  Found " $KRNL

#uncomment for debugging, also edit init-x86 to enable kernel & initrd messages
#DEBUG="console=ttyS0 console=tty0 ignore_loglevel"

echo "  Creating syslinux.cfg template for Syslinux Legacy BIOS"
echo "DEFAULT volumio

LABEL volumio
  SAY Legacy Boot Volumio Audiophile Music Player (default)
  LINUX ${KRNL}
  APPEND ro imgpart=LABEL=volumioimg bootpart=LABEL=volumioboot imgfile=volumio_current.sqsh quiet splash ${DEBUG}
  INITRD volumio.initrd
" > /boot/syslinux.cfg

echo "Installing Grub UEFI" 
echo "  Editing the grub config template"
# Make grub boot menu transparent
sed -i "s/menu_color_normal=cyan\/blue/menu_color_normal=white\/black/g" /etc/grub.d/05_debian_theme
sed -i "s/menu_color_highlight=white\/blue/menu_color_highlight=green\/dark-gray/g" /etc/grub.d/05_debian_theme
# replace the initrd string in the template
sed -i "s/initrd=\"\$i\"/initrd=\"volumio.initrd\"/g" /etc/grub.d/10_linux

#replace both LINUX_ROOT_DEVICE and LINUX_ROOT_DEVICE=UUID= in the template 
# to a string which we can replace after creating the grub config file
#TODO: update the default grub file
sed -i "s/LINUX_ROOT_DEVICE=\${GRUB_DEVICE}/LINUX_ROOT_DEVICE=imgpart=%%IMGPART%% /g" /etc/grub.d/10_linux
sed -i "s/LINUX_ROOT_DEVICE=UUID=\${GRUB_DEVICE_UUID}/LINUX_ROOT_DEVICE=imgpart=%%IMGPART%% /g" /etc/grub.d/10_linux

echo "  Creating grub config folder"
mkdir -p /boot/grub

echo "  Applying Grub Configuration"
grub-mkconfig -o /boot/grub/grub.cfg
chmod +w boot/grub/grub.cfg

echo "  Inserting root and boot partition label (building the boot cmdline used in initramfs)"
# Opting for finding partitions by-LABEL
sed -i "s/root=imgpart=%%IMGPART%%/imgpart=LABEL=volumioimg/g" /boot/grub/grub.cfg
sed -i "s/bootpart=%%BOOTPART%%/bootpart=LABEL=volumioboot/g" /boot/grub/grub.cfg

echo "  Prevent cgmanager starting during install (causing problems)" 
cat > /usr/sbin/policy-rc.d << EOF
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

echo "  Installing grub-efi-amd64 to make the 64bit UEFI bootloader"

apt-get update
apt-get -y install grub-efi-amd64-bin
grub-mkstandalone --compress=gz -O x86_64-efi -o /boot/efi/BOOT/BOOTX64.EFI -d /usr/lib/grub/x86_64-efi --modules="part_gpt part_msdos" --fonts="unicode" --locales="en@quot" --themes="" /boot/grub/grub.cfg
#we cannot install grub-efi-amd64 and grub-efi-ia32 on the same machine.
#on the off-chance that we need a 32bit bootloader, we remove amd64 and install ia32 to generate one
echo "  Uninstalling grub-efi-amd64"
apt-get -y --purge remove grub-efi-amd64-bin

echo "  Installing grub-efi-ia32 to make the 32bit UEFI bootloader"
apt-get -y install grub-efi-ia32-bin
grub-mkstandalone --compress=gz -O i386-efi -o /boot/efi/BOOT/BOOTIA32.EFI -d /usr/lib/grub/i386-efi --modules="part_gpt part_msdos" --fonts="unicode" --locales="en@quot" --themes="" /boot/grub/grub.cfg 
#and remove it again
echo "  Uninstalling grub-efi-ia32-bin"
apt-get -y --purge remove grub-efi-ia32-bin

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

echo "Editing fstab to use LABEL"
sed -i "s/%%BOOTPART%%/LABEL=volumioboot/g" /etc/fstab

echo "Setting up in kiosk-mode"
echo "  Creating chromium kiosk start script"
echo "#!/bin/bash

xset -dpms
xset s off
openbox-session &

while true; do
  rm -rf ~/.{config,cache}/chromium/
  /usr/bin/chromium --disable-session-crashed-bubble --disable-infobars --kiosk --no-first-run  'http://localhost:3000'
done" > /opt/volumiokiosk.sh
chmod +x /opt/volumiokiosk.sh

#echo "  Editing rc.local to start the chromium kiosk"
#sed -i "s|\\# By default this script does nothing.|\\nsudo -u volumio startx /etc/X11/Xsession /opt/volumiokiosk.sh|" /etc/rc.local
echo "[Unit]
Description=Start Volumio Kiosk
Wants=volumio.service
After=volumio.service
[Service]
Type=simple
User=volumio
Group=audio
ExecStart=/usr/bin/startx /etc/X11/Xsession /opt/volumiokiosk.sh
# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=300
[Install]
WantedBy=multi-user.target
" > /lib/systemd/system/volumio-kiosk.service
ln -s /lib/systemd/system/volumio-kiosk.service /etc/systemd/system/multi-user.target.wants/volumio-kiosk.service


echo "  Allowing volumio to start an xsession"
sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config

echo "Creating initramfs"
echo "  Adding custom modules"
echo "overlay" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules
echo "usbcore" >> /etc/initramfs-tools/modules
echo "usb_common" >> /etc/initramfs-tools/modules
echo "ehci_pci" >> /etc/initramfs-tools/modules
echo "ohci_pci" >> /etc/initramfs-tools/modules
echo "uhci_hcd" >> /etc/initramfs-tools/modules
echo "ehci_hcd" >> /etc/initramfs-tools/modules
echo "xhci_hcd" >> /etc/initramfs-tools/modules
echo "ohci_hcd" >> /etc/initramfs-tools/modules
echo "usbhid" >> /etc/initramfs-tools/modules
echo "hid_cherry" >> /etc/initramfs-tools/modules
echo "hid_generic" >> /etc/initramfs-tools/modules
echo "hid" >> /etc/initramfs-tools/modules
echo "nls_cp437" >> /etc/initramfs-tools/modules
echo "nls_utf8" >> /etc/initramfs-tools/modules
echo "vfat" >> /etc/initramfs-tools/modules

echo "  Copying volumio initramfs updater"
cd /root/
mv volumio-init-updater /usr/local/sbin

echo "  Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp

echo "  Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart

echo "Bootloader configuration and initrd.img complete"
