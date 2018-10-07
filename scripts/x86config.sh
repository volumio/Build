#!/bin/bash

PATCH=$(cat /patch)
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

echo "X86 USB Card Ordering"
echo "# USB DACs will have device number 5 in whole Volumio device range
options snd-usb-audio index=5" >> /etc/modprobe.d/alsa-base.conf

echo "Installing Syslinux Legacy BIOS"
syslinux -v
syslinux "${BOOT_PART}"

echo "Getting the current kernel filename"
KRNL=`ls -l /boot |grep vmlinuz | awk '{print $9}'`

echo "Creating run-time template for syslinux config"
DEBUG="USE_KMSG=no"
echo "DEFAULT volumio

LABEL volumio
  SAY Legacy Boot Volumio Audiophile Music Player (default)
  LINUX ${KRNL}
  APPEND ro imgpart=UUID=%%IMGPART%% bootpart=UUID=%%BOOTPART%% imgfile=volumio_current.sqsh quiet splash plymouth.ignore-serial-consoles vt.global_cursor_default=0 loglevel=0 ${DEBUG}
  INITRD volumio.initrd
" > /boot/syslinux.tmpl

echo "Creating syslinux.cfg from template"
cp /boot/syslinux.tmpl /boot/syslinux.cfg
sed -i "s/%%IMGPART%%/${UUID_IMG}/g" /boot/syslinux.cfg
sed -i "s/%%BOOTPART%%/${UUID_BOOT}/g" /boot/syslinux.cfg

echo "Editing the Grub UEFI config template"
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

echo "Setting plymouth image"
cp /usr/share/plymouth/themes/volumio/volumio-logo16.png /boot/volumio.png

echo "Creating Grub config folder"
mkdir /boot/grub

echo "Applying Grub configuration"
grub-mkconfig -o /boot/grub/grub.cfg
chmod +w /boot/grub/grub.cfg

echo "Coyping the new Grub config to the EFI bootloader folder"
cp /boot/grub/grub.cfg /boot/efi/BOOT/grub.cfg

echo "Telling the bootloader to read an external config" 
echo 'configfile ${cmdpath}/grub.cfg' > /grub-redir.cfg

echo "Using current grub.cfg as run-time template for kernel updates"
cp /boot/efi/BOOT/grub.cfg /boot/efi/BOOT/grub.tmpl
sed -i "s/${UUID_BOOT}/%%BOOTPART%%/g" /boot/efi/BOOT/grub.tmpl

echo "Inserting root and boot partition UUIDs (building the boot cmdline used in initramfs)"
# Opting for finding partitions by-UUID
sed -i "s/root=imgpart=%%IMGPART%%/imgpart=UUID=${UUID_IMG}/g" /boot/efi/BOOT/grub.cfg
sed -i "s/bootpart=%%BOOTPART%%/bootpart=UUID=${UUID_BOOT}/g" /boot/efi/BOOT/grub.cfg

cat > /usr/sbin/policy-rc.d << EOF
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

echo "Installing grub-efi-amd64 to make the 64bit UEFI bootloader"
apt-get update
apt-get -y install grub-efi-amd64-bin
grub-mkstandalone --compress=gz -O x86_64-efi -o /boot/efi/BOOT/BOOTX64.EFI "boot/grub/grub.cfg=grub-redir.cfg" -d /usr/lib/grub/x86_64-efi --modules="part_gpt part_msdos" --fonts="unicode" --themes=""
if [ ! -e /boot/efi/BOOT/BOOTX64.EFI ]; then
	echo "Fatal error, no 64bit bootmanager created, aborting..." 
    exit 1
fi

#we cannot install grub-efi-amd64 and grub-efi-ia32 on the same machine.
#on the off-chance that we need a 32bit bootloader, we remove amd64 and install ia32 to generate one
echo "Uninstalling grub-efi-amd64"
apt-get -y --purge remove grub-efi-amd64-bin

echo "Installing grub-efi-ia32 to make the 32bit UEFI bootloader"
apt-get -y install grub-efi-ia32-bin
grub-mkstandalone --compress=gz -O i386-efi -o /boot/efi/BOOT/BOOTIA32.EFI "boot/grub/grub.cfg=grub-redir.cfg" -d /usr/lib/grub/i386-efi --modules="part_gpt part_msdos" --fonts="unicode" --themes="" 
if [ ! -e /boot/efi/BOOT/BOOTIA32.EFI ]; then
	echo "Fatal error, no 32bit bootmanager created, aborting..." 
    exit 1
fi
#and remove it again
echo "Uninstalling grub-efi-ia32-bin and cleaning up grub install"
apt-get -y --purge remove grub-efi-ia32-bin
apt-get -y --purge remove efibootmgr libefivar0
rm /grub-redir.cfg
rm -r /boot/grub

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

echo "Copying fstab as a template to be used in initrd"
cp /etc/fstab /etc/fstab.tmpl

echo "Editing fstab to use UUID=<uuid of boot partition>"
sed -i "s/%%BOOTPART%%/UUID=${UUID_BOOT}/g" /etc/fstab

echo "Installing Japanese, Korean, Chinese and Taiwanese fonts"
apt-get -y install fonts-arphic-ukai fonts-arphic-gbsn00lp fonts-unfonts-core

echo "Configuring boot splash"
apt-get -y install plymouth plymouth-themes plymouth-x11
plymouth-set-default-theme volumio
echo "[Daemon]
Theme=volumio
ShowDelay=0
" > /usr/share/plymouth/plymouthd.defaults

echo "Setting up in kiosk-mode"
echo "Creating chromium kiosk start script"
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

echo "Hide Mouse cursor"

echo "#!/bin/sh

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

xrdb -merge ~/.Xresources         # aggiorna x resources db

#xscreensaver -no-splash &         # avvia il demone di xscreensaver
xsetroot -cursor_name left_ptr &  # setta il cursore di X
#sh ~/.fehbg &                     # setta lo sfondo con feh

exec openbox-session              # avvia il window manager

exec unclutter &" > /root/.xinitrc


echo "Allowing volumio to start an xsession"
sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config

echo "Creating initramfs"
echo "Adding custom modules"
echo "overlay" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules
echo "usbcore" >> /etc/initramfs-tools/modules
echo "usb_common" >> /etc/initramfs-tools/modules
echo "mmc_core" >> /etc/initramfs-tools/modules
echo "sdhci" >> /etc/initramfs-tools/modules
echo "sdhci_pci" >> /etc/initramfs-tools/modules
echo "sdhci_acpi" >> /etc/initramfs-tools/modules
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
echo "Adding ata modules for various chipsets"
cat /ata-modules.x86 >> /etc/initramfs-tools/modules
echo "Adding modules for Plymouth"
echo "intel_agp" >> /etc/initramfs-tools/modules
echo "drm" >> /etc/initramfs-tools/modules
echo "i915 modeset=1" >> /etc/initramfs-tools/modules
echo "nouveau modeset=1" >> /etc/initramfs-tools/modules
echo "radeon modeset=1" >> /etc/initramfs-tools/modules

echo "Copying volumio initramfs updater"
cd /root/
mv volumio-init-updater /usr/local/sbin

echo "Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp

echo "No need to keep the original initrd"
DELFILE=`ls -l /boot |grep initrd.img | awk '{print $9}'`
echo "Found "$DELFILE", deleting"
rm /boot/${DELFILE}
echo "No need for the system map either"
DELFILE=`ls -l /boot |grep System.map | awk '{print $9}'`
echo "Found "$DELFILE", deleting"
rm /boot/${DELFILE}

#On The Fly Patch
if [ "$PATCH" = "volumio" ]; then
echo "No Patch To Apply"
else
echo "Applying Patch ${PATCH}"
PATCHPATH=/${PATCH}
cd $PATCHPATH
#Check the existence of patch script
if [ -f "patch.sh" ]; then
sh patch.sh
else
echo "Cannot Find Patch File, aborting"
fi
if [ -f "install.sh" ]; then
sh install.sh
fi
cd /
rm -rf ${PATCH}
fi
rm /patch


echo "Bootloader configuration and initrd.img complete"
