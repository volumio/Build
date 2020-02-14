#!/bin/bash
# set -eo pipefail
# Reimport helpers in chroot
# shellcheck source=./scripts/helpers.sh
source /helpers.sh
export -f log
export -f time_it

function exit_error()
{
  log "Chroot config script failed" "$(basename "$0")" "err"
}

trap exit_error INT ERR

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.

echo "Creating Fstab File"

touch /etc/fstab
echo "proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab

echo "Adding PI Modules"
echo "
i2c-dev
" >> /etc/modules

echo "Alsa Raspberry PI Card Ordering"
echo "
options snd-usb-audio nrpacks=1
# USB DACs will have device number 5 in whole Volumio device range
options snd-usb-audio index=5
options snd_bcm2835 index=0" >> /etc/modprobe.d/alsa-base.conf

echo "Adding Raspberrypi.org Repo"
echo "deb http://archive.raspberrypi.org/debian/ buster main ui
deb-src http://archive.raspberrypi.org/debian/ buster main ui
" >> /etc/apt/sources.list.d/raspi.list

echo "Adding archive.volumio.org PGP Keys"
#curl -s http://archive.volumio.org/debian/raspberrypi.gpg.key |  apt-key add -
#curl -s http://archive.volumio.org/raspbian/raspbian.public.key |  apt-key add -

#echo "Adding Raspberrypi.org Repo Key"
curl -s http://archive.raspberrypi.org/debian/raspberrypi.gpg.key | apt-key add -
#echo "TEMP FIX FOR APT MIRROR"
#echo "APT::Get::AllowUnauthenticated "true";" > /etc/apt/apt.conf.d/98tempfix


echo "Installing R-pi specific binaries"
apt-get update
apt-get -y install binutils i2c-tools

echo "Installing Kernel from Rpi-Update"
echo "Fixing Curl CA "
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Temporary fix for PI4 check partition, until it gets merged
curl -L --output /usr/bin/rpi-update https://raw.githubusercontent.com/volumio/rpi-update/master/rpi-update
#sudo curl -L --output /usr/bin/rpi-update https://raw.githubusercontent.com/hexxeh/rpi-update/master/rpi-update && sudo chmod +x /usr/bin/rpi-update
chmod +x /usr/bin/rpi-update

touch /boot/start.elf
mkdir /lib/modules


KERNEL_VERSION="4.19.86"

case $KERNEL_VERSION in
    # "4.4.9")
    #   KERNEL_REV="884"
    #   KERNEL_COMMIT="15ffab5493d74b12194e6bfc5bbb1c0f71140155"
    #   FIRMWARE_COMMIT="9108b7f712f78cbefe45891bfa852d9347989529"
    #   ;;
    # "4.9.65")
    #   KERNEL_REV="1056"
    #   KERNEL_COMMIT="e4b56bb7efe47319e9478cfc577647e51c48e909"
    #   FIRMWARE_COMMIT=$KERNEL_COMMIT
    #   ;;
    # "4.9.80")
    #   KERNEL_REV="1098"
    #   KERNEL_COMMIT="936a8dc3a605c20058fbb23672d6b47bca77b0d5"
    #   FIRMWARE_COMMIT=$KERNEL_COMMIT
    #   ;;
    # "4.14.42")
    #   KERNEL_REV="1114"
    #   KERNEL_COMMIT="d68045945570b418ac48830374366613de3278f3"
    #   FIRMWARE_COMMIT=$KERNEL_COMMIT
    #   ;;
    # "4.14.56")
    #   KERNEL_REV="1128"
    #   KERNEL_COMMIT="d985893ae67195d0cce632efe4437e5fcde4b64b"
    #   FIRMWARE_COMMIT=$KERNEL_COMMIT
    #   ;;
    # "4.14.62")
    #   KERNEL_REV="1134"
    #   KERNEL_COMMIT="911147a3276beee09afc4237e1b7b964e61fb88a"
    #   FIRMWARE_COMMIT=$KERNEL_COMMIT
    #   ;;
    # "4.14.71")
    #   KERNEL_REV="1145"
    #   KERNEL_COMMIT="c919d632ddc2a88bcb87b7d0cddd61446d1a36bf"
    #   FIRMWARE_COMMIT=$KERNEL_COMMIT
    #   ;;
    # "4.14.92")
    #   KERNEL_REV="1187"
    #   KERNEL_COMMIT="6aec73ed5547e09bea3e20aa2803343872c254b6"
    #   FIRMWARE_COMMIT=$KERNEL_COMMIT
    #   ;;
    "4.19.56")
      KERNEL_REV="1242"
      KERNEL_COMMIT="5ed750aaca6aa04c53dbe4f90942e4bb138a1ba6"
      FIRMWARE_COMMIT=$KERNEL_COMMIT
      ;;
    "4.19.60")
      KERNEL_REV="1247"
      KERNEL_COMMIT="ce2a9f85a6fd88f8c42ef54b7bad99b42e76e403"
      FIRMWARE_COMMIT=$KERNEL_COMMIT
      ;;
    "4.19.75")
      KERNEL_REV="1270"
      KERNEL_COMMIT="d9321aceacfc6619b4238c6c764203b1122f2f9b"
      FIRMWARE_COMMIT=$KERNEL_COMMIT
      ;;
    "4.19.79")
      KERNEL_REV="1273"
      KERNEL_COMMIT="985bc5353e4f5fe5a11c8b6c4c646dc7165bbc21"
      FIRMWARE_COMMIT=$KERNEL_COMMIT
      ;;
    "4.19.86")
      KERNEL_REV="1283"
      KERNEL_COMMIT="b9ecbe8d0e3177afed08c54fc938938100a0b73f"
      FIRMWARE_COMMIT=$KERNEL_COMMIT
      ;;
esac

# using rpi-update relevant to defined kernel version
echo y | SKIP_BACKUP=1 WANT_PI4=1 SKIP_CHECK_PARTITION=1 UPDATE_SELF=0 /usr/bin/rpi-update $KERNEL_COMMIT

echo "Getting actual kernel revision with firmware revision backup"
cp /boot/.firmware_revision /boot/.firmware_revision_kernel

echo "Updating bootloader files *.elf *.dat *.bin"
echo y | SKIP_KERNEL=1 WANT_PI4=1 SKIP_CHECK_PARTITION=1 UPDATE_SELF=0 /usr/bin/rpi-update $FIRMWARE_COMMIT

if [ -d /lib/modules/$KERNEL_VERSION-v8+ ]; then
  echo "Removing v8+ (pi4) Kernels"
  rm /boot/kernel8.img
  rm -rf /lib/modules/$KERNEL_VERSION-v8+
fi

apt-get update
echo "Blocking unwanted libraspberrypi0, raspberrypi-bootloader, raspberrypi-kernel installs"
# these packages critically update kernel & firmware files and break Volumio
# may be triggered by manual or plugin installs explicitly or through dependencies like chromium, sense-hat, picamera,...
echo "Package: raspberrypi-bootloader
Pin: release *
Pin-Priority: -1

Package: raspberrypi-kernel
Pin: release *
Pin-Priority: -1" > /etc/apt/preferences
echo "Disabling apt-mark for now"
apt-mark hold raspberrypi-kernel raspberrypi-bootloader #libraspberrypi0 depends on raspberrypi-bootloader

echo "Adding PI3 & PiZero W Wireless, PI WIFI Wireless dongle, ralink mt7601u & few others firmware upgrading to Pi Foundations packages"
apt-get install -y --only-upgrade firmware-atheros firmware-ralink firmware-realtek firmware-brcm80211

# Temporary brcm firmware fix solution until we use Buster
#wget http://repo.volumio.org/Volumio2/Firmwares/firmware-brcm80211_20190114-1+rpt2_all.deb
#dpkg -i firmware-brcm80211_20190114-1+rpt2_all.deb
#rm firmware-brcm80211_20190114-1+rpt2_all.deb

# if [ "$KERNEL_VERSION" = "4.4.9" ]; then       # probably won't be necessary in future kernels
# echo "Adding initial support for PiZero W wireless on 4.4.9 kernel"
# wget -P /boot/. https://github.com/Hexxeh/rpi-firmware/raw/$FIRMWARE_COMMIT/bcm2708-rpi-0-w.dtb
# echo "Adding support for dtoverlay=pi3-disable-wifi on 4.4.9 kernel"
# wget -P /boot/overlays/. https://github.com/Hexxeh/rpi-firmware/raw/$FIRMWARE_COMMIT/overlays/pi3-disable-wifi.dtbo
# fi

echo "Installing WiringPi from Raspberrypi.org Repo"
apt-get -y install wiringpi

echo "Configuring boot splash"
apt-get -y install plymouth plymouth-themes
plymouth-set-default-theme volumio

echo "Removing unneeded binaries"
apt-get -y remove binutils
apt-get -y autoremove

echo "Writing config.txt file"
echo "initramfs volumio.initrd
gpu_mem=32
max_usb_current=1
dtparam=audio=on
audio_pwm_mode=2
dtparam=i2c_arm=on
disable_splash=1
hdmi_force_hotplug=1
enable_uart=1
dtoverlay=pi3-miniuart-bt

include userconfig.txt" >> /boot/config.txt

echo "Writing cmdline.txt file"
# echo "splash quiet plymouth.ignore-serial-consoles dwc_otg.fiq_enable=1 dwc_otg.fiq_fsm_enable=1 dwc_otg.fiq_fsm_mask=0xF dwc_otg.nak_holdoff=1 console=serial0,115200 kgdboc=serial0,115200 console=tty1 imgpart=/dev/mmcblk0p2 imgfile=/volumio_current.sqsh elevator=noop rootwait bootdelay=5 logo.nologo vt.global_cursor_default=0 loglevel=0" >> /boot/cmdline.txt
echo "earlycon=serial0,115200 dwc_otg.fiq_enable=1 dwc_otg.fiq_fsm_enable=1 dwc_otg.fiq_fsm_mask=0xF dwc_otg.nak_holdoff=1 console=serial0,115200 kgdboc=serial0,115200 console=tty1 imgpart=/dev/mmcblk0p2 imgfile=/volumio_current.sqsh elevator=noop rootwait bootdelay=5 logo.nologo vt.global_cursor_default=0 loglevel=8" >> /boot/cmdline.txt

echo "adding gpio & spi group and permissions"
groupadd -f --system gpio
groupadd -f --system spi

echo "adding volumio to gpio group and al"
usermod -a -G gpio,i2c,spi,input volumio

echo "Installing raspberrypi-sys-mods System customization (& removing few bits)"
apt-get -y install raspberrypi-sys-mods
rm /etc/sudoers.d/010_pi-nopasswd
unlink /etc/systemd/system/multi-user.target.wants/sshswitch.service
rm /lib/systemd/system/sshswitch.service

echo "Installing Bluetooth Utils"
apt-get install -y bluez bluez-firmware pi-bluetooth

echo "Exporting /opt/vc/bin variable"
export LD_LIBRARY_PATH=/opt/vc/lib/:LD_LIBRARY_PATH

echo "Adding custom modules"
echo "squashfs" >> /etc/initramfs-tools/modules
echo "overlay" >> /etc/initramfs-tools/modules

echo "Customizing pre and post actions for dtoverlay"

echo "echo 'pre'" > /opt/vc/bin/dtoverlay-pre
chmod a+x /opt/vc/bin/dtoverlay-pre
echo "echo 'post'" > /opt/vc/bin/dtoverlay-post
chmod a+x /opt/vc/bin/dtoverlay-post

echo "DTOverlay utility"

ln -s /opt/vc/lib/libdtovl.so /usr/lib/libdtovl.so
ln -s /opt/vc/bin/dtoverlay /usr/bin/dtoverlay
ln -s /opt/vc/bin/dtoverlay-pre /usr/bin/dtoverlay-pre
ln -s /opt/vc/bin/dtoverlay-post /usr/bin/dtoverlay-post

echo "Setting Vcgencmd"

ln -s /opt/vc/lib/libvchiq_arm.so /usr/lib/libvchiq_arm.so
ln -s /opt/vc/bin/vcgencmd /usr/bin/vcgencmd
ln -s /opt/vc/lib/libvcos.so /usr/lib/libvcos.so

# changing external ethX priority rule for Pi as built-in eth _is_ on USB (smsc95xx or lan78xx drivers)
sed -i 's/KERNEL==\"eth/DRIVERS!=\"smsc95xx\", DRIVERS!=\"lan78xx\", &/' /etc/udev/rules.d/99-Volumio-net.rules

echo "Installing Wireless drivers for 8188eu, 8192eu, 8812au, mt7610, and mt7612. Many thanks MrEngman"
### We cache the drivers archives upon first request on Volumio server, to relieve stress on mr engmans
# MRENGMAN_REPO="http://wifi-drivers.volumio.org/wifi-drivers"
# #MRENGMAN_REPO="http://downloads.fars-robotics.net/wifi-drivers"
# mkdir wifi
# cd wifi
#
# for DRIVER in 8188eu 8192eu 8812au mt7610 mt7612
# do
#   echo "WIFI: $DRIVER for armv7l"
#   wget $MRENGMAN_REPO/$DRIVER-drivers/$DRIVER-$KERNEL_VERSION-v7l-$KERNEL_REV.tar.gz
#   tar xf $DRIVER-$KERNEL_VERSION-v7l-$KERNEL_REV.tar.gz
#   sed -i 's/^kernel=.*$/kernel='"$KERNEL_VERSION"'-v7l+/' install.sh
#   sh install.sh
#   rm -rf *
#
#   echo "WIFI: $DRIVER for armv7"
#   wget $MRENGMAN_REPO/$DRIVER-drivers/$DRIVER-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
#   tar xf $DRIVER-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
#   sed -i 's/^kernel=.*$/kernel='"$KERNEL_VERSION"'-v7+/' install.sh
#   sh install.sh
#   rm -rf *
#
#   echo "WIFI: $DRIVER for armv6"
#   wget $MRENGMAN_REPO/$DRIVER-drivers/$DRIVER-$KERNEL_VERSION-$KERNEL_REV.tar.gz
#   tar xf $DRIVER-$KERNEL_VERSION-$KERNEL_REV.tar.gz
#   sed -i 's/^kernel=.*$/kernel='"$KERNEL_VERSION"'+/' install.sh
#   sh install.sh
#   rm -rf *
# done
#
# cd ..
# rm -rf wifi

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


if [ "$PATCH" = "volumio" ] || [ "$PATCH" = "my-volumio" ]; then

echo "Adding third party Firmware"
cd /
echo "Getting Allo Piano Firmware"
wget --no-check-certificate  https://github.com/allocom/piano-firmware/archive/master.tar.gz
echo "Extracting Allo Firmwares"
tar xf master.tar.gz
cp -rp /piano-firmware-master/* /
rm -rf /piano-firmware-master
rm /README.md
rm master.tar.gz
echo "Allo firmware installed"

echo "Getting TauDAC Modules and overlay"
wget https://github.com/taudac/modules/archive/rpi-volumio-"$KERNEL_VERSION"-taudac-modules.tar.gz
echo "Extracting TauDAC Modules and overlay"
tar --strip-components 1 --exclude *.hash -xf rpi-volumio-"$KERNEL_VERSION"-taudac-modules.tar.gz
rm rpi-volumio-"$KERNEL_VERSION"-taudac-modules.tar.gz
echo "TauDAC Modules and overlay installed"

echo "Getting Volumio driver"
wget http://repo.volumio.org/Volumio2/Firmwares/ess-volumio/ess-volumio-$KERNEL_VERSION-v7+.tar.gz
tar xf ess-volumio-$KERNEL_VERSION-v7+.tar.gz --no-same-owner
rm ess-volumio-$KERNEL_VERSION-v7+.tar.gz


# Upstreamed!
# if [ "$KERNEL_VERSION" = "4.4.9" ]; then
#
# ### Allo I2S Modules
# echo "Getting Allo DAC Modules"
# wget http://repo.volumio.org/Volumio2/Firmwares/rpi-volumio-4.4.9-AlloDAC-modules.tgz
# echo "Extracting Allo DAC modules"
# tar xf rpi-volumio-4.4.9-AlloDAC-modules.tgz
# rm rpi-volumio-4.4.9-AlloDAC-modules.tgz
#
# echo "Allo modules installed"
#
# echo "Adding Pisound Kernel Module and dtbo"
# wget http://repo.volumio.org/Volumio2/Firmwares/rpi-volumio-4.4.9-pisound-modules.tgz
# echo "Extracting  PiSound Modules"
# tar xf rpi-volumio-4.4.9-pisound-modules.tgz
# rm rpi-volumio-4.4.9-pisound-modules.tgz
# fi

fi

echo "Installing winbind here, since it freezes networking"
apt-get install -y winbind libnss-winbind

echo "Finalising drivers installation with depmod on $KERNEL_VERSION+ and $KERNEL_VERSION-v7+"
depmod $KERNEL_VERSION+     # Pi 1, Zero, Compute Module
depmod $KERNEL_VERSION-v7+  # Pi 2,3 CM3
depmod $KERNEL_VERSION-v7l+ # Pi4

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

#First Boot operations
echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart

echo "Reduce initramfs size by setting MODULES=dep"
# sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf

echo "Enable serial boot debug"
if [[ -f /boot/bootcode.bin ]]; then
  sed -i -e "s/BOOT_UART=0/BOOT_UART=1/" /boot/bootcode.bin
else
  echo "No /boot/bootcode.bin yet!"
fi

echo "Creating initramfs"
mkinitramfs-buster.sh -o /tmp/initramfs-tmp
