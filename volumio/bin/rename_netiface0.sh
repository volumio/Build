#!/bin/sh
# This script is called by Volumio udev rule to set/swap name to eth0 or wlan0
# as udev renaming sometimes fails with some module drivers
# it assumes legacy style interface names such as ethX, wlanX


if_name=$1
if_type=${if_name%%[0-9]*}

ifconfig $if_type"0" down
ifconfig $if_name down
ip link set dev $if_type"0" name temp_name
ip link set dev $if_name name $if_type"0"
ip link set dev temp_name name $if_name
ifconfig $if_name up
ifconfig $if_type"0" up
