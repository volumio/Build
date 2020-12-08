#!/usr/bin/env bash

RAMSIZE=$(grep MemTotal /proc/meminfo | awk '{ print $2 }')
SWAPDEVS=$(wc -l </proc/swaps)
SWAPDIR="/swap"
SWAPFILE="${SWAPDIR}/swapfile"

if [[ "${RAMSIZE}" -le 512844 ]] && [[ ${SWAPDEVS} -le 1 ]]; then
    echo "512 MB or less RAM Detected, need to enable swap"
    [[ -d ${SWAPDIR} ]] || mkdir -m 700 ${SWAPDIR}
    mount -L volumio_data ${SWAPDIR}
    if [ ! -e ${SWAPFILE} ]; then
        echo "No Swapfile present, creating it..."
        fallocate -l 512M ${SWAPFILE}
        echo "Securing Swap permissions"
        chown root:root ${SWAPFILE}
        chmod 0600 ${SWAPFILE}
        echo "Preparing SwapFile"
        mkswap ${SWAPFILE}
    fi

    echo "Enabling Swap"
    swapon ${SWAPFILE}
    echo "Setting swappiness to 40"
    sysctl vm.swappiness=40
fi
