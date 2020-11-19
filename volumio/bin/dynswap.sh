#!/bin/sh

RAMSIZE=`cat /proc/meminfo | grep MemTotal | awk '{ print $2 }'`
SWAPDEVS=`cat /proc/swaps | wc -l`

if [ ${RAMSIZE} -le 512844 -a ${SWAPDEVS} -le 1 ]; then
    echo "512 MB or less RAM Detected, need to enable swap"
    [ -d /swap ] || mkdir -m 700 /swap
    mount -L volumio_data /swap
    if [ ! -e /swap/swapfile ]; then
	echo "No Swapfile present, creating it..."
	fallocate -l 512M /swap/swapfile
	echo "Securing Swap permissions"
	chown root:root /swap/swapfile
	chmod 0600 /swap/swapfile
	echo "Preparing SwapFile"
	mkswap /swap/swapfile
    fi
	
    echo "Enabling Swap"
    swapon /swap/swapfile
    echo "Setting swappiness to 40"
    sysctl vm.swappiness=40
fi
