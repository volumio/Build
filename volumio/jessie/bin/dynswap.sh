#!/bin/sh

RAMSIZE=`cat /proc/meminfo | grep MemTotal | awk '{ print $2 }'`
SWAPDEVS=`cat /proc/swaps | wc -l`

if [ ${RAMSIZE} -le 512844 -a ${SWAPDEVS} -le 1 ]; then
    echo "512 MB or less RAM Detected, need to enable swap"
    if [ ! -e /data/swapfile ]; then
	echo "No Swapfile present, creating it..."
	fallocate -l 512M /data/swapfile
	echo "Securing Swap permissions"
	chown root:root /data/swapfile
	chmod 0600 /data/swapfile
	echo "Preparing SwapFile"
	mkswap /data/swapfile
    fi
	
    echo "Enabling Swap"
    swapon /data/swapfile
    echo "Setting swappiness to 40"
    sysctl vm.swappiness=40
fi
