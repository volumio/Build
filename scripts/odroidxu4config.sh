#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.

# ***************
# Create fstab
# ***************
echo "Creating fstab"
echo "# Odroid fstab
 
/dev/mmcblk0p2  /        ext4    errors=remount-ro,rw,noatime,nodiratime  0 1
/dev/mmcblk0p1  /boot    vfat    defaults,ro,owner,flush,umask=000        0 0
tmpfs           /var/log tmpfs   defaults,noatime,mode=0755				  0 0
tmpfs			/var/log/volumio tmpfs size=20M,nodev,mode=0777           0 0
tmpfs			/var/log/mpd tmpfs size=20M,nodev,mode=0777           0 0
tmpfs           /tmp     tmpfs   nodev,nosuid,mode=1777                   0 0
" > /mnt/volumio/etc/fstab


echo "Prevent services starting during install, running under chroot" 
echo "(avoids unnecessary errors)"
cat > /usr/sbin/policy-rc.d << EOF
exit 101
EOF
chmod +x /usr/sbin/policy-rc.d

echo "Installing additonal packages"
apt-get update

#on-going: get firmware for e.g. wireless modules
# Refer to: http://cdimage.debian.org/cdimage/unofficial/non-free/firmware/
echo "Installing additional firmware"
apt-get -y install firmware-realtek firmware-ralink firmware-atheros

echo "Adding volumio-remote-updater"
wget -P /usr/local/bin/ http://updates.volumio.org/jx

wget -P /usr/local/sbin/ http://updates.volumio.org/volumio-remote-updater.jx
chmod +x /usr/local/sbin/volumio-remote-updater.jx /usr/local/bin/jx

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

echo "Tweaking: disable energy sensor error message"
echo "blacklist ina231_sensor" >> /etc/modprobe.d/blacklist-odroid.conf
echo "Tweaking: optimize fan-control"
echo "DRIVER==\"odroid-fan\", ACTION==\"add\", ATTR{fan_speeds}=\"1 20 50 95\", ATTR{temp_levels}=\"50 70 80\"" > /etc/udev/rules.d/60-odroid_fan.rules
echo "Enabling Fan Control Servcie"
mv /opt/fan-control/odroid-xu3-fan-control.service /lib/systemd/system
systemctl enable odroid-xu3-fan-control.service

#On The Fly Patch
if [ $PATCH == "volumio" ]; then
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

