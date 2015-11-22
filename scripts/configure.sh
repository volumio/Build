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
echo 'Copying ARM related configuration files'
cp volumio/etc/apt/sources.list build/$BUILD/root/etc/apt/sources.list
elif [ "$BUILD" = x86 ]; then
echo 'Copying X86 related Configuration files' 
#APT sources file
cp volumio/etc/apt/sources.list.x86 build/$BUILD/root/etc/apt/sources.list
#Grub2 conf file
cp volumio/etc/default/grub build/$BUILD/root/etc/default/grub
#FSTAB File
cp volumio/etc/fstab.x86 build/$BUILD/root/etc/fstab
fi
#Edimax Power Saving Fix + Alsa modprobe
cp -r volumio/etc/modprobe.d build/$BUILD/root/etc/
#Hosts file 
cp -p volumio/etc/hosts build/$BUILD/root/etc/hosts
#Dhcp conf file
cp volumio/etc/dhcp/dhclient.conf build/$BUILD/root/etc/dhcp/dhclient.conf
#Samba conf file
cp volumio/etc/samba/smb.conf build/$BUILD/root/etc/samba/smb.conf
#Udev confs file (NET and USB)
cp -r volumio/etc/udev build/$BUILD/root/etc/
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
# Netplug
cp -rp volumio/etc/netplug build/$BUILD/root/etc/
# IpTables Rules
cp volumio/etc/iptables.rules build/$BUILD/root/etc/iptables.rules
cp -r volumio/etc/network/* build/$BUILD/root/etc/network
echo 'Done Copying Custom Volumio System Files'

