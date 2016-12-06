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
tmpfs   /var/log                tmpfs   nodev 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults        0 0
" > /etc/fstab

echo "Adding PI Modules"
echo "
snd_bcm2835
i2c-dev
i2c-bcm2708
" >> /etc/modules

echo "Alsa Raspberry PI Card Ordering"
echo "
options snd-usb-audio nrpacks=1
# USB DACs will have device number 5 in whole Volumio device range
options snd-usb-audio index=5
options snd_bcm2835 index=0" >> /etc/modprobe.d/alsa-base.conf


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

echo y | SKIP_BACKUP=1 rpi-update 15ffab5493d74b12194e6bfc5bbb1c0f71140155

echo "Adding PI3 Wireless firmware"
wget http://repo.volumio.org/Volumio2/wireless-firmwares/brcmfmac43430-sdio.txt -P /lib/firmware/brcm/
wget http://repo.volumio.org/Volumio2/wireless-firmwares/brcmfmac43430-sdio.bin -P /lib/firmware/brcm/

echo "Adding PI WIFI Wireless firmware"
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
force_turbo=1
max_usb_current=1
dtparam=audio=on
dtparam=i2c_arm=on
disable_splash=1" >> /boot/config.txt


echo "Writing cmdline.txt file"
echo "force_turbo=1 dwc_otg.lpm_enable=0  dwc_otg.fiq_enable=1 dwc_otg.fiq_fsm_enable=1 dwc_otg.fiq_fsm_mask=0x3 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 imgpart=/dev/mmcblk0p2 imgfile=/volumio_current.sqsh elevator=noop rootwait smsc95xx.turbo_mode=N " >> /boot/cmdline.txt

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


### Allo I2S Firmware


echo "Getting Allo Modules"
cd /
wget http://repo.volumio.org/Volumio2/Firmwares/volumio-RPi4.4.9_pianoDACplus.tgz
echo "Extracting Allo modules"
tar xf volumio-RPi4.4.9_pianoDACplus.tgz
rm volumio-RPi4.4.9_pianoDACplus.tgz

echo "Getting Allo Firmwares"
wget http://repo.volumio.org/Volumio2/Firmwares/alloPianoDACfw_22112016.tgz
echo "Extracting Allo Firmwares"
tar xf alloPianoDACfw_22112016.tgz
rm alloPianoDACfw_22112016.tgz
echo "Allo modules and firmware installed"

echo "Adding license info"

echo "You may royalty free distribute object and executable versions of the TI component libraries, and its derivatives 
(“derivative” shall mean adding the TI component library to an audio signal flow of a product to make a new audio signal chain without
changing the algorithm of the TI component library), to use and integrate the software with any other software, these files are only
licensed to be used on the TI  PCM 5142 DAC IC , but are freely distributable and re-distributable , subject to acceptance of the license 
agreement, including executable only versions of the TI component libraries, or its derivatives, that execute solely and exclusively with 
the PCM5142 Audio DAC and not with Audio DAC Devices manufactured by or for an entity other than TI, and (ii) is sold by or for an original
 equipment manufacturer (“OEM”) bearing such OEM brand name and part number.
" >  /lib/firmware/alloPiano/LICENSE

#First Boot operations

echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart


echo "Creating initramfs"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp
