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
tmpfs   /var/log                tmpfs   nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/cache/apt/archives tmpfs   defaults,noexec,nosuid,nodev,mode=0755 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults        0 0
" > /etc/fstab

echo "Adding BCM Module"
echo "
snd_bcm2835
" >> /etc/modules

echo "Alsa Raspberry PI Card Ordering"
echo "
options snd-usb-audio nrpacks=1
# USB DACs will have device number 5 in whole Volumio device range
options snd-usb-audio index=5
options snd_bcm2835 index=0" >> /etc/modprobe.d/alsa-base.conf


echo "Installing R-pi specific binaries"
apt-get update
apt-get -y install binutils
# Commenting raspi-config, not sure it is really needed
#apt-get -y install libnewt0.52 whiptail triggerhappy lua5.1 locales

echo "Installing Kernel from Rpi-Update"
sudo curl -L --output /usr/bin/rpi-update https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update && sudo chmod +x /usr/bin/rpi-update
touch /boot/start.elf
mkdir /lib/modules

# Kernel 4.1.18 for Pi3 Support
echo y | SKIP_BACKUP=1 rpi-update 6e8b794818e06f50724774df3b1d4c6be0b5708c

echo "Adding PI3 Wireless firmware"
wget https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm80211/brcm/brcmfmac43430-sdio.bin -P /lib/firmware/brcm
wget https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm80211/brcm/brcmfmac43430-sdio.txt -P /lib/firmware/brcm

#echo "Adding raspi-config"
#wget -P /raspi http://archive.raspberrypi.org/debian/pool/main/r/raspi-config/raspi-config_20151019_all.deb
#dpkg -i /raspi/raspi-config_20151019_all.deb
#rm -Rf /raspi

echo "Removing unneeded binaries"
apt-get -y remove binutils

echo "Writing config.txt file"
echo "initramfs volumio.initrd 
gpu_mem=16 
force_turbo=1
max_usb_current=1" >> /boot/config.txt


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

#First Boot operations

echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart


echo "Creating initramfs"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp
