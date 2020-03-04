#!/bin/sh
##
#Volumio system Configuration Script
##

while getopts ":b:" opt; do
  case $opt in
    b)
      BUILD=$OPTARG
      ;;
  esac
done

echo 'Copying Custom Volumio System Files'
#Apt conf file
if [ "$BUILD" = arm ] || [ "$BUILD" = armv7 ]; then
  echo 'Copying ARM related configuration files'
  cp volumio/buster/etc/apt/sources.list.${BUILD} build/$BUILD/root/etc/apt/sources.list
  echo 'Setting time for ARM devices with fakehwclock to build time'
  date -u '+%Y-%m-%d %H:%M:%S' > build/$BUILD/root/etc/fake-hwclock.data
elif [ "$BUILD" = x86 ]; then
  echo 'Copying X86 related Configuration files'
  #APT sources file
  cp volumio/buster/etc/apt/sources.list.${BUILD} build/$BUILD/root/etc/apt/sources.list
#Grub2 conf file
  cp volumio/buster/etc/default/grub build/$BUILD/root/etc/default/grub
  cp volumio/buster/splash/volumio.png build/$BUILD/root/boot
#FSTAB File
  cp volumio/buster/etc/fstab.x86 build/$BUILD/root/etc/fstab
else
  echo 'Unexpected Build Architecture, aborting...'
  exit 1
fi
#Edimax Power Saving Fix + Alsa modprobe
cp -r volumio/buster/etc/modprobe.d build/$BUILD/root/etc/
#Hosts file
cp -p volumio/buster/etc/hosts build/$BUILD/root/etc/hosts
#Dhcp conf file
cp volumio/buster/etc/dhcp/dhclient.conf build/$BUILD/root/etc/dhcp/dhclient.conf
cp volumio/buster/etc/dhcp/dhcpd.conf build/$BUILD/root/etc/dhcp/dhcpd.conf
#Samba conf file
cp volumio/buster/etc/samba/smb.conf build/$BUILD/root/etc/samba/smb.conf
#Udev confs file (NET)
cp -r volumio/buster/etc/udev build/$BUILD/root/etc/
#Activate NODE_MOUNT_HANDLER
sed -i "s/NODE_MOUNT_HANDLER=false/NODE_MOUNT_HANDLER=true/g" build/$BUILD/root/volumio/.env

#Polkit for USB mounts
cp -r volumio/buster/etc/polkit-1/localauthority/50-local.d/50-mount-as-pi.pkla build/$BUILD/root/etc/polkit-1/localauthority/50-local.d/50-mount-as-pi.pkla
#Inittab file
cp volumio/buster/etc/inittab build/$BUILD/root/etc/inittab
#MOTD
cp volumio/buster/etc/motd build/$BUILD/root/etc/motd
#SSH
cp volumio/buster/etc/ssh/sshd_config build/$BUILD/root/etc/ssh/sshd_config
#Mpd
cp volumio/buster/etc/mpd.conf build/$BUILD/root/etc/mpd.conf
chmod 777 build/$BUILD/root/etc/mpd.conf
#Log via JournalD in RAM
cp volumio/buster/etc/systemd/journald.conf build/$BUILD/root/etc/systemd/journald.conf
#Volumio SystemD Services
cp -r volumio/buster/lib build/$BUILD/root/

# Netplug
# removed , we are using ifplugd
#cp -rp volumio/buster/etc/netplug build/$BUILD/root/etc/
#chmod +x build/$BUILD/root/etc/netplug/netplug
# Network
cp -r volumio/buster/etc/network/* build/$BUILD/root/etc/network
# Wpa Supplicant
echo " " > build/$BUILD/root/etc/wpa_supplicant/wpa_supplicant.conf
chmod 777 build/$BUILD/root/etc/wpa_supplicant/wpa_supplicant.conf
#Shairport
cp volumio/buster/etc/shairport-sync.conf build/$BUILD/root/etc/shairport-sync.conf
chmod 777 build/$BUILD/root/etc/shairport-sync.conf
#nsswitch
cp volumio/buster/etc/nsswitch.conf build/$BUILD/root/etc/nsswitch.conf
#firststart
cp volumio/buster/bin/firststart.sh build/$BUILD/root/bin/firststart.sh
#hotspot
cp volumio/buster/bin/hotspot.sh build/$BUILD/root/bin/hotspot.sh
#dynswap
cp volumio/buster/bin/dynswap.sh build/$BUILD/root/bin/dynswap.sh
#Wireless
cp volumio/buster/bin/wireless.js build/$BUILD/root/volumio/app/plugins/system_controller/network/wireless.js
#dhcpcd
cp -rp volumio/buster/etc/dhcpcd.conf build/$BUILD/root/etc/
#wifi pre script
cp volumio/buster/bin/wifistart.sh build/$BUILD/root/bin/wifistart.sh
chmod a+x build/$BUILD/root/bin/wifistart.sh
#udev script
cp volumio/buster/bin/rename_netiface0.sh build/$BUILD/root/bin/rename_netiface0.sh
chmod a+x build/$BUILD/root/bin/rename_netiface0.sh
#Plymouth & upmpdcli files
cp -rp volumio/buster/usr/*  build/$BUILD/root/usr/
#SSH
cp volumio/buster/bin/volumiossh.sh build/$BUILD/root/bin/volumiossh.sh
chmod a+x build/$BUILD/root/bin/volumiossh.sh
#CPU TWEAK
cp volumio/buster/bin/volumio_cpu_tweak build/$BUILD/root/bin/volumio_cpu_tweak
chmod a+x build/$BUILD/root/bin/volumio_cpu_tweak
#LAN HOTPLUG
cp volumio/buster/etc/default/ifplugd build/$BUILD/root/etc/default/ifplugd

echo 'Done Copying Custom Volumio System Files'

echo "Stripping binaries and libraries to save space"

#echo "Size before strip"$( du -sh build/$BUILD/root/ )
#find build/$BUILD/root/usr/lib -type f -name \*.a  -exec strip --strip-debug {} ';'
#find build/$BUILD/root/usr/lib -type f -name \*.so* -exec strip --strip-unneeded {} ';'
#find build/$BUILD/root/lib -type f -name \*.so* -exec strip --strip-unneeded {} ';'
#find build/$BUILD/root/sbin -type f -exec strip --strip-all {} ';'
#find build/$BUILD/root/bin -type f -exec strip --strip-all {} ';'
#find build/$BUILD/root/usr/bin -type f -exec strip --strip-all {} ';'
#find build/$BUILD/root/usr/sbin -type f -exec strip --strip-all {} ';'
#echo "Size after strip"$( du -sh build/$BUILD/root/ )
