#!/bin/bash

case "$1" in
'start')
DRIVER=`/sbin/ethtool -i wlan0 | grep driver | awk -F": " '{print $2}'`

if [ $DRIVER = "rtl8192cu" ] ; then
  echo "Launching Hostapd Edimax"
/usr/sbin/hostapd-edimax /etc/hostapd/hostapd.conf
else
  echo "LaunghingOrdinary Hostapd"
/usr/sbin/hostapd /etc/hostapd/hostapd.conf
fi
;;
'stop')

echo "Killing Hostapd"
/usr/bin/sudo /usr/bin/killall hostapd

echo "Killing Dhcpd"
/usr/bin/sudo /usr/bin/killall dhcpd
;;
esac
