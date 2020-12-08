#!/bin/bash

PATCH=$(cat /patch)

# This script will be run in chroot under qemu.

echo "Initializing.."
. init.sh

echo "Creating \"fstab\""
echo "# (so)Pine64(lts) fstab" > /etc/fstab
echo "" >> /etc/fstab
echo "proc            /proc           proc    defaults        0       0
UUID=${UUID_BOOT}  /boot           vfat    defaults,utf8,user,rw,umask=111,dmask=000        0       1
tmpfs   /var/log                tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4, 0 0
tmpfs   /var/spool/cups         tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /var/spool/cups/tmp     tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /tmp                    tmpfs   defaults,noatime,mode=0755 0 0
tmpfs   /dev/shm                tmpfs   defaults,nosuid,noexec,nodev        0 0
" > /etc/fstab

echo "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
echo "abi.cp15_barrier=2" >> /etc/sysctl.conf

echo "Adding 'unmute headphone' script"
echo "#!/bin/bash
CARD=\`aplay -l | grep \"Headphone Out\" | awk -F'[^0-9]*' '{print \$2}'\`
STATE=\`amixer -c $CARD cget numid=13 | grep \": values=\" | awk -F'[=]' '{print \$2}'\`

if [ $STATE == off,off ]; then
   amixer -c $CARD cset numid=13 on
   amixer -c $CARD sget 'AIF1 Slot 0 Digital DAC'
else
   echo \"Already enabled\"
fi

exit 0
"> /etc/rc.local

echo "Installing additonal packages"
apt-get update
apt-get -y install u-boot-tools liblircclient0 lirc libcdio-dev libcdparanoia-dev bluez-firmware bluetooth bluez bluez-tools

echo "Enabling Bluetooth Adapter auto-poweron"
echo "[Policy]
AutoEnable=true" >> /etc/bluetooth/main.conf 

echo "Cleaning APT Cache and remove policy file"
rm -f /var/lib/apt/lists/*archive*
apt-get clean

echo "Adding custom modules overlayfs, squashfs and nls_cp437"
echo "overlay" >> /etc/initramfs-tools/modules
echo "squashfs" >> /etc/initramfs-tools/modules
echo "nls_cp437" >> /etc/initramfs-tools/modules

echo "Copying volumio initramfs updater"
cd /root/
mv volumio-init-updater /usr/local/sbin

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

echo "Changing to 'modules=list'"
echo "(reduce uInitrd size)"
sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf

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
rm /boot/volumio.initrd

