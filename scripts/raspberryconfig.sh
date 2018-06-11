#!/bin/bash

while getopts ":v:" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
  esac
done

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
echo "deb http://archive.raspberrypi.org/debian/ jessie main ui
deb-src http://archive.raspberrypi.org/debian/ jessie main ui
" >> /etc/apt/sources.list.d/raspi.list

echo "Adding Raspberrypi.org Repo Key"
wget http://archive.raspberrypi.org/debian/raspberrypi.gpg.key -O - | sudo apt-key add -

echo "Installing R-pi specific binaries"
apt-get update
apt-get -y install binutils i2c-tools
# Commenting raspi-config, not sure it is really needed
#apt-get -y install libnewt0.52 whiptail triggerhappy lua5.1 locales

echo "Installing Kernel from Rpi-Update"
sudo curl -L --output /usr/bin/rpi-update https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update && sudo chmod +x /usr/bin/rpi-update
touch /boot/start.elf
mkdir /lib/modules


KERNEL_VERSION="4.14.42"

case $KERNEL_VERSION in
    "4.4.9")
      KERNEL_REV="884"
      KERNEL_COMMIT="15ffab5493d74b12194e6bfc5bbb1c0f71140155"
      FIRMWARE_COMMIT="9108b7f712f78cbefe45891bfa852d9347989529"
      ;; 
    "4.9.65")
      KERNEL_REV="1056"
      KERNEL_COMMIT="e4b56bb7efe47319e9478cfc577647e51c48e909"
      FIRMWARE_COMMIT=$KERNEL_COMMIT
      ;; 
    "4.9.80")
      KERNEL_REV="1098"
      KERNEL_COMMIT="936a8dc3a605c20058fbb23672d6b47bca77b0d5"
      FIRMWARE_COMMIT=$KERNEL_COMMIT
      ;;
    "4.14.42")
      KERNEL_REV="1114"
      KERNEL_COMMIT="d68045945570b418ac48830374366613de3278f3"
      FIRMWARE_COMMIT=$KERNEL_COMMIT
      ;;
esac

# using rpi-update relevant to defined kernel version
echo y | SKIP_BACKUP=1 rpi-update $KERNEL_COMMIT

echo "Getting actual kernel revision with firmware revision backup"
cp /boot/.firmware_revision /boot/.firmware_revision_kernel

echo "Updating bootloader files *.elf *.dat *.bin"
echo y | SKIP_KERNEL=1 rpi-update $FIRMWARE_COMMIT

echo "Blocking unwanted libraspberrypi0, raspberrypi-bootloader, raspberrypi-kernel installs"
# these packages critically update kernel & firmware files and break Volumio
# may be triggered by manual or plugin installs explicitly or through dependencies like chromium, sense-hat, picamera,...
echo "Package: raspberrypi-bootloader
Pin: release *
Pin-Priority: -1

Package: raspberrypi-kernel
Pin: release *
Pin-Priority: -1" > /etc/apt/preferences
apt-mark hold raspberrypi-kernel raspberrypi-bootloader   #libraspberrypi0 depends on raspberrypi-bootloader

echo "Adding PI3 & PiZero W Wireless, PI WIFI Wireless dongle, ralink mt7601u & few others firmware upgraging to Pi Foundations packages"
apt-get install -y --only-upgrade firmware-atheros firmware-ralink firmware-realtek firmware-brcm80211

# Temporary brcm firmware fix solution until we use Stretch
wget http://repo.volumio.org/Volumio2/Firmwares/firmware-brcm80211_20161130-3%2Brpt3_all.deb
dpkg -i firmware-brcm80211_20161130-3+rpt3_all.deb
rm firmware-brcm80211_20161130-3+rpt3_all.deb

if [ "$KERNEL_VERSION" = "4.4.9" ]; then       # probably won't be necessary in future kernels 
echo "Adding initial support for PiZero W wireless on 4.4.9 kernel"
wget -P /boot/. https://github.com/Hexxeh/rpi-firmware/raw/$FIRMWARE_COMMIT/bcm2708-rpi-0-w.dtb
echo "Adding support for dtoverlay=pi3-disable-wifi on 4.4.9 kernel"
wget -P /boot/overlays/. https://github.com/Hexxeh/rpi-firmware/raw/$FIRMWARE_COMMIT/overlays/pi3-disable-wifi.dtbo
fi

#echo "Adding raspi-config"
#wget -P /raspi http://archive.raspberrypi.org/debian/pool/main/r/raspi-config/raspi-config_20151019_all.deb
#dpkg -i /raspi/raspi-config_20151019_all.deb
#rm -Rf /raspi

echo "Installing WiringPi from Raspberrypi.org Repo"
apt-get -y install wiringpi

echo "Configuring boot splash"
apt-get -y install plymouth plymouth-themes
plymouth-set-default-theme volumio

echo "Removing unneeded binaries"
apt-get -y remove binutils

echo "Writing config.txt file"
echo "initramfs volumio.initrd
gpu_mem=16
max_usb_current=1
dtparam=audio=on
audio_pwm_mode=2
dtparam=i2c_arm=on
disable_splash=1
hdmi_force_hotplug=1" >> /boot/config.txt

echo "Writing cmdline.txt file"
echo "splash quiet plymouth.ignore-serial-consoles dwc_otg.fiq_enable=1 dwc_otg.fiq_fsm_enable=1 dwc_otg.fiq_fsm_mask=0xF dwc_otg.nak_holdoff=1 console=serial0,115200 kgdboc=serial0,115200 console=tty1 imgpart=/dev/mmcblk0p2 imgfile=/volumio_current.sqsh elevator=noop rootwait bootdelay=5 logo.nologo vt.global_cursor_default=0 loglevel=0" >> /boot/cmdline.txt

echo "adding gpio & spi group and permissions"
groupadd -f --system gpio
groupadd -f --system spi

echo "adding volumio to gpio group and al"
usermod -a -G gpio,i2c,spi,input volumio

echo "Installing raspberrypi-sys-mods System customizations (& removing few bits)"
apt-get -y install raspberrypi-sys-mods
rm /etc/sudoers.d/010_pi-nopasswd
unlink /etc/systemd/system/multi-user.target.wants/sshswitch.service
rm /lib/systemd/system/sshswitch.service

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
MRENGMAN_REPO="http://wifi-drivers.volumio.org/wifi-drivers"
#MRENGMAN_REPO="http://downloads.fars-robotics.net/wifi-drivers"
mkdir wifi
cd wifi

for DRIVER in 8188eu 8192eu 8812au mt7610 mt7612
do
  echo "WIFI: $DRIVER for armv7"
  wget $MRENGMAN_REPO/$DRIVER-drivers/$DRIVER-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
  tar xf $DRIVER-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
  sed -i 's/^kernel=.*$/kernel='"$KERNEL_VERSION"'-v7+/' install.sh
  sh install.sh
  rm -rf *

  echo "WIFI: $DRIVER for armv6"
  wget $MRENGMAN_REPO/$DRIVER-drivers/$DRIVER-$KERNEL_VERSION-$KERNEL_REV.tar.gz
  tar xf $DRIVER-$KERNEL_VERSION-$KERNEL_REV.tar.gz
  sed -i 's/^kernel=.*$/kernel='"$KERNEL_VERSION"'+/' install.sh
  sh install.sh
  rm -rf *
done

cd ..
rm -rf wifi

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


if [ "$PATCH" = "volumio" ]; then

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


if [ "$KERNEL_VERSION" = "4.4.9" ]; then

### Allo I2S Modules
echo "Getting Allo DAC Modules"
wget http://repo.volumio.org/Volumio2/Firmwares/rpi-volumio-4.4.9-AlloDAC-modules.tgz
echo "Extracting Allo DAC modules"
tar xf rpi-volumio-4.4.9-AlloDAC-modules.tgz
rm rpi-volumio-4.4.9-AlloDAC-modules.tgz

echo "Allo modules installed"

echo "Adding Pisound Kernel Module and dtbo"
wget http://repo.volumio.org/Volumio2/Firmwares/rpi-volumio-4.4.9-pisound-modules.tgz
echo "Extracting  PiSound Modules"
tar xf rpi-volumio-4.4.9-pisound-modules.tgz
rm rpi-volumio-4.4.9-pisound-modules.tgz
fi

fi

echo "Installing winbind here, since it freezes networking"
apt-get install -y winbind libnss-winbind

echo "Finalising drivers installation with depmod on $KERNEL_VERSION+ and $KERNEL_VERSION-v7+"
depmod $KERNEL_VERSION+
depmod $KERNEL_VERSION-v7+

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

#First Boot operations
echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart


echo "Creating initramfs"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp
