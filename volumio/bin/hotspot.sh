#!/bin/bash

INTERFACE=wlan0

case "$1" in
  'start')
    modulepath=$(readlink /sys/class/net/${INTERFACE}/device/driver/module)
    if [ "X" = "X$modulepath" ]; then
        # Sometimes there is no wireless interface
        echo "Unable to find driver module name for interface $INTERFACE"
        echo "Exiting early"
        exit 1
    else
        # Normal case
        MODULE=$(basename "$modulepath")
    fi
    ARCH=`/usr/bin/dpkg --print-architecture`

    if [ "$MODULE" = "8192cu" ] && [ "$ARCH" = "armhf" ] && !(modinfo "$MODULE" | grep -q '^depends:.*cfg80211.*') ; then
      echo "Launching Hostapd Edimax"
    /usr/sbin/hostapd-edimax /etc/hostapd/hostapd-edimax.conf
    else
      echo "Launching Ordinary Hostapd"
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
