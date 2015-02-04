#!/bin/sh
##
#Volumio system Configuration Script
##

echo 'Copying Custom Volumio System Files'
#Apt conf file
cp volumio/etc/apt/sources.list build/root/etc/apt/sources.list
#Dhcp conf file
cp volumio/etc/dhcp/dhclient.conf build/root/etc/dhcp/dhclient.conf
#Samba conf file
cp volumio/etc/samba/smb.conf build/root/etc/samba/smb.conf
#Udev confs file (NET and USB)
cp -r volumio/etc/udev build/root/etc/udev
#Inittab file
cp volumio/etc/inittab build/root/etc/inittab
#MOTD
cp volumio/etc/motd build/root/etc/motd
#SSH
cp volumio/etc/ssh/sshd_config build/root/etc/ssh/sshd_config
#Mpd
cp volumio/etc/mpd.conf build/root/etc/mpd.conf
#Log via JournalD in RAM
cp volumio/etc/systemd/journald.conf build/root/etc/systemd/journald.conf
#Volumio SystemD Services
cp -r volumio/lib build/root/

echo 'Done Copying Custom Volumio System Files'

