#!/bin/bash
##
#Volumio system Configuration Script
##

set -eo pipefail
function exit_error()
{
  log "Volumio config failed" "err" "$(basename "$0")"
}

trap exit_error INT ERR


while getopts ":b:" opt; do
  case $opt in
    b)
      BUILD=$OPTARG
      ;;
    *)
      log "Unknown $OPTARG passed to configure.sh" "err"
  esac
done

log 'Copying Custom Volumio System Files' "info"
#Apt conf file
if [ "$BUILD" = arm ] || [ "$BUILD" = armv7 ] || [ "$BUILD" = armv8 ]; then
  log 'Copying ARM sources configuration files'
  cp volumio/etc/apt/sources.list.$BUILD build/$BUILD/root/etc/apt/sources.list
  log 'Setting time for ARM devices with fakehwclock to build time'
  date -u '+%Y-%m-%d %H:%M:%S' > build/$BUILD/root/etc/fake-hwclock.data
elif [ "$BUILD" = x86 ]; then
  log 'Copying X86 related Configuration files'
  #APT sources file
  cp volumio/etc/apt/sources.list.x86 build/$BUILD/root/etc/apt/sources.list
#Grub2 conf file
  cp volumio/etc/default/grub build/$BUILD/root/etc/default/grub
  cp volumio/splash/volumio.png build/$BUILD/root/boot
#FSTAB File
  cp volumio/etc/fstab.x86 build/$BUILD/root/etc/fstab
else
  log 'Unexpected Build Architecture, aborting...' "err"
  exit 1
fi

log "Copying misc config to rootfs"

#Edimax Power Saving Fix + Alsa modprobe
cp -r volumio/etc/modprobe.d build/$BUILD/root/etc/
#Hosts file
cp -p volumio/etc/hosts build/$BUILD/root/etc/hosts
#Dhcp conf file
cp volumio/etc/dhcp/dhclient.conf build/$BUILD/root/etc/dhcp/dhclient.conf
cp volumio/etc/dhcp/dhcpd.conf build/$BUILD/root/etc/dhcp/dhcpd.conf
#Samba conf file
cp volumio/etc/samba/smb.conf build/$BUILD/root/etc/samba/smb.conf
#Udev confs file (NET)
cp -r volumio/etc/udev build/$BUILD/root/etc/
#Polkit for USB mounts
cp -r volumio/etc/polkit-1/localauthority/50-local.d/50-mount-as-pi.pkla build/$BUILD/root/etc/polkit-1/localauthority/50-local.d/50-mount-as-pi.pkla
#Inittab file
cp volumio/etc/inittab build/$BUILD/root/etc/inittab
#MOTD
cp volumio/etc/motd build/$BUILD/root/etc/motd
#SSH
cp volumio/etc/ssh/sshd_config build/$BUILD/root/etc/ssh/sshd_config
#Mpd
cp volumio/etc/mpd.conf build/$BUILD/root/etc/mpd.conf
chmod 777 build/$BUILD/root/etc/mpd.conf
#Log via JournalD in RAM
cp volumio/etc/systemd/journald.conf build/$BUILD/root/etc/systemd/journald.conf
#Volumio SystemD Services
cp -r volumio/lib build/$BUILD/root/
# Netplug
# removed , we are using ifplugd
#cp -rp volumio/etc/netplug build/$BUILD/root/etc/
#chmod +x build/$BUILD/root/etc/netplug/netplug
# Network
cp -r volumio/etc/network/* build/$BUILD/root/etc/network
# Wpa Supplicant
echo " " > build/$BUILD/root/etc/wpa_supplicant/wpa_supplicant.conf
chmod 777 build/$BUILD/root/etc/wpa_supplicant/wpa_supplicant.conf
#Shairport
cp volumio/etc/shairport-sync.conf build/$BUILD/root/etc/shairport-sync.conf
chmod 777 build/$BUILD/root/etc/shairport-sync.conf
#nsswitch
cp volumio/etc/nsswitch.conf build/$BUILD/root/etc/nsswitch.conf
#firststart
cp volumio/bin/firststart.sh build/$BUILD/root/bin/firststart.sh
#hotspot
cp volumio/bin/hotspot.sh build/$BUILD/root/bin/hotspot.sh
#dynswap
cp volumio/bin/dynswap.sh build/$BUILD/root/bin/dynswap.sh
#Wireless
cp volumio/bin/wireless.js build/$BUILD/root/volumio/app/plugins/system_controller/network/wireless.js
#dhcpcd
cp -rp volumio/etc/dhcpcd.conf build/$BUILD/root/etc/
#wifi pre script
cp volumio/bin/wifistart.sh build/$BUILD/root/bin/wifistart.sh
chmod a+x build/$BUILD/root/bin/wifistart.sh
#udev script
cp volumio/bin/rename_netiface0.sh build/$BUILD/root/bin/rename_netiface0.sh
chmod a+x build/$BUILD/root/bin/rename_netiface0.sh
#Plymouth & upmpdcli files
cp -rp volumio/usr/*  build/$BUILD/root/usr/
#SSH
cp volumio/bin/volumiossh.sh build/$BUILD/root/bin/volumiossh.sh
chmod a+x build/$BUILD/root/bin/volumiossh.sh
#CPU TWEAK
cp volumio/bin/volumio_cpu_tweak build/$BUILD/root/bin/volumio_cpu_tweak
chmod a+x build/$BUILD/root/bin/volumio_cpu_tweak
#LAN HOTPLUG
cp volumio/etc/default/ifplugd build/$BUILD/root/etc/default/ifplugd

log 'Done Copying Custom Volumio System Files' "okay"

log "Stripping binaries and libraries to save space"

#echo "Size before strip"$( du -sh build/$BUILD/root/ )
#find build/$BUILD/root/usr/lib -type f -name \*.a  -exec strip --strip-debug {} ';'
#find build/$BUILD/root/usr/lib -type f -name \*.so* -exec strip --strip-unneeded {} ';'
#find build/$BUILD/root/lib -type f -name \*.so* -exec strip --strip-unneeded {} ';'
#find build/$BUILD/root/sbin -type f -exec strip --strip-all {} ';'
#find build/$BUILD/root/bin -type f -exec strip --strip-all {} ';'
#find build/$BUILD/root/usr/bin -type f -exec strip --strip-all {} ';'
#find build/$BUILD/root/usr/sbin -type f -exec strip --strip-all {} ';'
#echo "Size after strip"$( du -sh build/$BUILD/root/ )
