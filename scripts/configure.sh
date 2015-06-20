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
if [ "$BUILD" = arm ]; then
echo 'ARM'
cp volumio/etc/apt/sources.list build/$BUILD/root/etc/apt/sources.list
elif [ "$BUILD" = x86 ]; then
echo 'X86' 
cp volumio/etc/apt/sources.list.x86 build/$BUILD/root/etc/apt/sources.list
fi
#Dhcp conf file
cp volumio/etc/dhcp/dhclient.conf build/$BUILD/root/etc/dhcp/dhclient.conf
#Samba conf file
cp volumio/etc/samba/smb.conf build/$BUILD/root/etc/samba/smb.conf
#Udev confs file (NET and USB)
cp -r volumio/etc/udev build/$BUILD/root/etc/udev
#Inittab file
cp volumio/etc/inittab build/$BUILD/root/etc/inittab
#MOTD
cp volumio/etc/motd build/$BUILD/root/etc/motd
#SSH
cp volumio/etc/ssh/sshd_config build/$BUILD/root/etc/ssh/sshd_config
#Mpd
cp volumio/etc/mpd.conf build/$BUILD/root/etc/mpd.conf
#Log via JournalD in RAM
cp volumio/etc/systemd/journald.conf build/$BUILD/root/etc/systemd/journald.conf
#Volumio SystemD Services
cp -r volumio/lib build/$BUILD/root/

echo 'Done Copying Custom Volumio System Files'

