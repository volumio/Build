#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.
echo "Initializing.."
. init.sh

echo "Creating \"fstab\""
echo "# Tinkerboard fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
UUID=${UUID_BOOT} /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab

echo "(Re-)Creating boot config"
echo "label kernel-4.4
    kernel /zImage
    fdt /dtb/rk3288-miniarm.dtb
    initrd /uInitrd
    append  earlyprintk splash plymouth.ignore-serial-consoles console=tty1 console=ttyS3,115200n8 rw init=/sbin/init imgpart=UUID=${UUID_IMG} imgfile=/volumio_current.sqsh bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA} bootconfig=/extlinux/extlinux.conf
" > /boot/extlinux/extlinux.conf 

echo "Adding default sound modules"
#echo "
#
#" >> /etc/modules

echo "USB Card Ordering"
echo "# USB DACs will have device number 5 in whole Volumio device range
# For tinkerboard, we specify that internal USB audio should be at device 1
options snd-usb-audio index=1,5 vid=0x0bda pid=0x481a" >> /etc/modprobe.d/alsa-base.conf

echo "#!/bin/sh
echo 2 > /proc/irq/45/smp_affinity
" > /usr/local/bin/tinker-init.sh
chmod +x /usr/local/bin/tinker-init.sh

echo "primodac=\`sudo /usr/sbin/i2cdetect -y 1 0x48 0x48 | grep -E 'UU|48' | awk '{print \$2}'\`
if [ ! -z \"\$primodac\" ]; then
  configured=\`cat /boot/hw_intf.conf | grep es90x8q2m-dac | awk -F '=' '{print \$2}'\`
  if [ -z \"\$configured\" ]; then
    echo \"For information only, you may safely delete this file\" > /boot/dacdetect.log
    echo \"\`date\`: Volumio Primo DAC detected on i2c address 0x48...\" >> /boot/dacdetect.log
    volumioconfigured=\`cat /boot/hw_intf.conf | grep \"#### Volumio i2s \" \`
    if [ ! -z \"\$volumioconfigured\" ]; then
      echo \"\`date\`: Another DAC configured, wiping it out...\" >> /boot/dacdetect.log
      mv /boot/hw_intf.conf /boot/hw_intf.tmp
      sed '/#### Volumio i2s setting below/Q' /boot/hw_intf.tmp >/boot/hw_intf.conf
      rm /boot/hw_intf.tmp
    fi
    echo \"\`date\`: Automatically configuring ES90x8Q2M and reboot...\" >> /boot/dacdetect.log
    echo \"#### Volumio i2s setting below: do not alter ####\" >> /boot/hw_intf.conf
    echo \"intf:dtoverlay=es90x8q2m-dac\" >> /boot/hw_intf.conf
    /sbin/reboot
  fi
fi" > /usr/local/bin/detect-primo.sh
chmod +x /usr/local/bin/detect-primo.sh

echo "#!/bin/sh -e
/usr/local/bin/tinker-init.sh
/usr/local/bin/detect-primo.sh
exit 0" > /etc/rc.local

echo "Installing Tinkerboard Bluetooth Utils and Firmware"
wget http://repo.volumio.org/Volumio2/Firmwares/rtl_bt_tinkerboard.tar.gz
tar xf rtl_bt_tinkerboard.tar.gz -C /
rm rtl_bt_tinkerboard.tar.gz
systemctl enable tinkerbt.service

echo "Installing additonal packages"
apt-get update
#apt-get -y install u-boot-tools liblircclient0 lirc
apt-get -y install u-boot-tools

echo "Configuring boot splash"
apt-get -y install plymouth plymouth-themes
plymouth-set-default-theme volumio

echo "Adding custom modules overlay, squashfs and nls_cp437"
echo "overlay" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules
echo "nls_cp437" >> /etc/initramfs-tools/modules

echo "Copying volumio initramfs updater"
cd /root/
mv volumio-init-updater /usr/local/sbin


echo "Installing Kiosk"
sh /install-kiosk.sh

echo "Kiosk installed"
rm /install-kiosk.sh
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

echo "Changing to 'modules=dep'"
sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf

echo "Installing winbind here, since it freezes networking"
apt-get update
apt-get install -y winbind libnss-winbind

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

#First Boot operations
echo "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart

echo "Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp

echo "Creating uInitrd from 'volumio.initrd'"
mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
echo "Cleaning up"
rm /boot/volumio.initrd
