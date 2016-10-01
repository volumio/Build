#!/bin/sh

RAMSIZE=`cat /proc/meminfo | grep MemTotal | awk '{ print $2 }'`

if [ ${RAMSIZE} -le 512844 ]; then
	echo "512 MB or less RAM Detected, need to enable swap"
    if [ -e /data/swapfile ]; then
    echo "Enabling Swap"
    swapon /data/swapfile
    else
    echo "No Swapfile present, creating it..."
	dd if=/dev/zero of=/data/swapfile bs=1024 count=524288
	echo "Securing Swap permissions"
	chown root:root /data/swapfile
	chmod 0600 /data/swapfile
	echo "Preparing SwapFile"
	mkswap /data/swapfile
	echo "Enabling Swap"
	swapon /data/swapfile
    fi
fi
