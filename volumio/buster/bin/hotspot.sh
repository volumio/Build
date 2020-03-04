#!/bin/bash

HARDWARE=$(cat /etc/os-release | grep ^VOLUMIO_HARDWARE | tr -d 'VOLUMIO_HARDWARE="')
KERNEL_VERSION=$(uname -r | cut -d. -f1-2 --output-delimiter='')
KERNEL_VERSION_HOSTAPD28="419"

case "$1" in
  'start')
    MODULE=$(basename $(readlink /sys/class/net/wlan0/device/driver/module))
    ARCH=`/usr/bin/dpkg --print-architecture`

    if [ "$MODULE" = "8192cu" ] && [ "$ARCH" = "armhf" ] && !(modinfo "$MODULE" | grep -q '^depends:.*cfg80211.*') ; then
      echo "Launching Hostapd Edimax"
      /usr/sbin/hostapd-edimax /etc/hostapd/hostapd-edimax.conf
    else
      if [[ $KERNEL_VERSION == $KERNEL_VERSION_HOSTAPD28 ]] && [ $HARDWARE == "pi" ] ; then
        echo "Launching Hostapd 2.8"
        /usr/sbin/hostapd-2.8 /etc/hostapd/hostapd.conf
      else
        echo "Launching Ordinary Hostapd"
        /usr/sbin/hostapd /etc/hostapd/hostapd.conf
      fi
    fi
  ;;

  'stop')
    echo "Killing Hostapd"
    /usr/bin/sudo /usr/bin/killall hostapd

    echo "Killing Dhcpd"
    /usr/bin/sudo /usr/bin/killall dhcpd
    ;;
esac
