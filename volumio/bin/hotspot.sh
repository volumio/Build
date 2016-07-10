#!/bin/bash

DRIVER=`/sbin/ethtool -i wlan0 | grep driver | awk -F": " '{print $2}'`

if [ $DRIVER = "rtl8192cu" ] ; then
  echo "Launching Hostapd Edimax"
/usr/sbin/hostapd-edimax /etc/hostapd/hostapd.conf
else
  echo "LaunghingOrdinary Hostapd"
/usr/sbin/hostapd /etc/hostapd/hostapd.conf
fi
