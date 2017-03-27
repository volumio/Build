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
wget https://www.raspberrypi.org/raspberrypi.gpg.key -O - | sudo apt-key add -

echo "Installing R-pi specific binaries"
apt-get update
apt-get -y install binutils i2c-tools
# Commenting raspi-config, not sure it is really needed
#apt-get -y install libnewt0.52 whiptail triggerhappy lua5.1 locales

echo "Installing Kernel from Rpi-Update"
sudo curl -L --output /usr/bin/rpi-update https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update && sudo chmod +x /usr/bin/rpi-update
touch /boot/start.elf
mkdir /lib/modules

# Kernel 4.4.9 for Pi3 Support
# see https://github.com/raspberrypi/firmware/commit/cc6d7bf8b4c03a2a660ff9fdf4083fc165620866
# and https://github.com/Hexxeh/rpi-firmware/issues/118
KERNEL_VERSION="4.4.9"
KERNEL_REV="884"

# using rpi-update stable branch for 4.4.y as master is now on 4.9.y
echo y | SKIP_BACKUP=1 BRANCH=stable rpi-update 15ffab5493d74b12194e6bfc5bbb1c0f71140155

echo "Updating bootloader files *.elf *.dat *.bin"
echo y | SKIP_KERNEL=1 BRANCH=stable rpi-update

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

if [ "$KERNEL_VERSION" = "4.4.9" ]; then       # probably won't be necessary in future kernels 
echo "Adding initial support for PiZero W wireless on 4.4.9 kernel"
wget -P /boot/. https://github.com/raspberrypi/firmware/raw/stable/boot/bcm2708-rpi-0-w.dtb
echo "Adding support for dtoverlay=pi3-disable-wifi on 4.4.9 kernel"
wget -P /boot/overlays/. https://github.com/raspberrypi/firmware/raw/stable/boot/overlays/pi3-disable-wifi.dtbo
fi

echo "Adding PI3 & PiZero W Wireless firmware"
wget http://repo.volumio.org/Volumio2/wireless-firmwares/brcmfmac43430-sdio.txt -P /lib/firmware/brcm/
wget http://repo.volumio.org/Volumio2/wireless-firmwares/brcmfmac43430-sdio.bin -P /lib/firmware/brcm/

echo "Adding PI WIFI Wireless dongle firmware"
wget http://repo.volumio.org/Volumio2/wireless-firmwares/brcmfmac43143.bin -P /lib/firmware/brcm/

#echo "Adding raspi-config"
#wget -P /raspi http://archive.raspberrypi.org/debian/pool/main/r/raspi-config/raspi-config_20151019_all.deb
#dpkg -i /raspi/raspi-config_20151019_all.deb
#rm -Rf /raspi

echo "Installing WiringPi"
wget http://repo.volumio.org/Volumio2/Binaries/wiringpi_2.24_armhf.deb
dpkg -i wiringpi_2.24_armhf.deb
rm /wiringpi_2.24_armhf.deb


echo "adding gpio group and permissions"
cd /
wget http://repo.volumio.org/Volumio2/Binaries/gpio-admin.tar.gz
tar xvf gpio-admin.tar.gz
rm /gpio-admin.tar.gz
groupadd -f --system gpio
chgrp gpio /usr/local/bin/gpio-admin
chmod u=rwxs,g=rx,o= /usr/local/bin/gpio-admin

touch /lib/udev/rules.d/91-gpio.rules
echo 'KERNEL=="spidev*", GROUP="spi", MODE="0660"
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c' "'chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio; chown -R root:gpio /sys/devices/virtual/gpio && chmod -R 770 /sys/devices/virtual/gpio; chown -R root:gpio /sys/devices/platform/soc/*.gpio/gpio && chmod -R 770 /sys/devices/platform/soc/*.gpio/gpio'"'"' > /lib/udev/rules.d/91-gpio.rules

echo "adding volumio to gpio group"
sudo adduser volumio gpio

echo "Fixing crda domain error"
apt-get -y install crda wireless-regdb

echo "Removing unneeded binaries"
apt-get -y remove binutils

echo "Writing config.txt file"
echo "initramfs volumio.initrd
gpu_mem=16
max_usb_current=1
dtparam=audio=on
dtparam=i2c_arm=on
disable_splash=1" >> /boot/config.txt


echo "Writing cmdline.txt file"
echo "dwc_otg.lpm_enable=0 dwc_otg.fiq_enable=1 dwc_otg.fiq_fsm_enable=1 dwc_otg.fiq_fsm_mask=0x3 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 imgpart=/dev/mmcblk0p2 imgfile=/volumio_current.sqsh elevator=noop rootwait smsc95xx.turbo_mode=N " >> /boot/cmdline.txt

echo "Cleaning APT Cache"
rm -f /var/lib/apt/lists/*archive*
apt-get clean

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

echo "Adding raspi blackist"
#this way if another USB WIFI dongle is present, it will always be the default one
echo "
#wifi
blacklist brcmfmac
blacklist brcmutil
" > /etc/modprobe.d/raspi-blacklist.conf

#Load PI3 wifi module just before wifi stack starts
echo "
#!/bin/sh
sudo /sbin/modprobe brcmfmac
sudo /sbin/modprobe brcmutil
sudo /sbin/iw dev wlan0 set power_save off
" >> /bin/wifistart.sh
echo "Give proper permissions to wifistart.sh"
chmod a+x /bin/wifistart.sh

echo "Installing Wireless drivers for 8192eu, 8812au, 8188eu and mt7610. Many thanks mrengman"
MRENGMAN_REPO="http://www.fars-robotics.net"
mkdir wifi
cd wifi

echo "WIFI: 8192EU for armv7"
wget $MRENGMAN_REPO/8192eu-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
tar xf 8192eu-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
./install.sh
rm -rf *

echo "WIFI: 8192EU for armv6"
wget $MRENGMAN_REPO/8192eu-$KERNEL_VERSION-$KERNEL_REV.tar.gz
tar xf 8192eu-$KERNEL_VERSION-$KERNEL_REV.tar.gz
./install.sh
rm -rf *

echo "WIFI: 8812AU for armv7"
wget $MRENGMAN_REPO/8812au-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
tar xf 8812au-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
./install.sh
rm -rf *

echo "WIFI: 8812AU for armv6"
wget $MRENGMAN_REPO/8812au-$KERNEL_VERSION-$KERNEL_REV.tar.gz
tar xf 8812au-$KERNEL_VERSION-$KERNEL_REV.tar.gz
./install.sh
rm -rf *

echo "WIFI: 8188EU for armv7"
wget $MRENGMAN_REPO/8188eu-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
tar xf 8188eu-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
./install.sh
rm -rf *

echo "WIFI: 8188EU for armv6"
wget $MRENGMAN_REPO/8188eu-$KERNEL_VERSION-$KERNEL_REV.tar.gz
tar xf 8188eu-$KERNEL_VERSION-$KERNEL_REV.tar.gz
./install.sh
rm -rf *

echo "WIFI: MT7610 for armv7"
wget $MRENGMAN_REPO/mt7610-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
tar xf mt7610-$KERNEL_VERSION-v7-$KERNEL_REV.tar.gz
./install.sh
rm -rf *

echo "WIFI: MT7610 for armv6"
wget $MRENGMAN_REPO/mt7610-$KERNEL_VERSION-$KERNEL_REV.tar.gz
tar xf mt7610-$KERNEL_VERSION-$KERNEL_REV.tar.gz
./install.sh
rm -rf *

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
cd /
rm -rf ${PATCH}
fi
rm /patch


if [ "$PATCH" = "volumio" ]; then
### Allo I2S Firmware
echo "Getting Allo Modules"
cd /
echo "Getting Allo DAC Modules"
wget http://repo.volumio.org/Volumio2/Firmwares/rpi-volumio-4_4_9-AlloDAC-modules.tgz
echo "Extracting Allo DAC modules"
tar xf rpi-volumio-4_4_9-AlloDAC-modules.tgz
rm rpi-volumio-4_4_9-AlloDAC-modules.tgz

echo "Getting Allo BOSS Firmwares"
wget http://repo.volumio.org/Volumio2/Firmwares/volumio-RPi4.4.9_boss_03022017.tgz
echo "Extracting Allo Firmwares"
tar xf volumio-RPi4.4.9_boss_03022017.tgz
rm volumio-RPi4.4.9_boss_03022017.tgz

echo "Getting Allo Piano Firmwares"
wget --no-check-certificate  https://github.com/allocom/piano-firmware/archive/master.tar.gz
echo "Extracting Allo Firmwares"
tar xf master.tar.gz
cp -rp /piano-firmware-master/* /
rm -rf /piano-firmware-master 
rm /README.md
rm master.tar.gz

echo "Allo modules and firmware installed"

echo "Adding Pisound Kernel Module and dtbo"
wget http://repo.volumio.org/Volumio2/Firmwares/pisound_volumio_4.4.9.tar.gz
echo "Extracting  PiSound Modules"
tar xf pisound_volumio_4.4.9.tar.gz
rm pisound_volumio_4.4.9.tar.gz

echo "Adding Aoide-DACs Kernel Module and dtbo"
wget https://github.com/howardqiao/volumio2-aoide-drivers/raw/master/aoide_volumio_4.4.9.tar.gz
echo "Extracting Aoide-DACs Modules"
tar xf aoide_volumio_4.4.9.tar.gz
rm aoide_volumio_4.4.9.tar.gz
fi

echo "Installing winbind here, since it freezes networking"
apt-get update
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
