#!/bin/bash

KERNEL="4.4.9"

echo "Volumio first start configuration script"

echo "Doing Depmod, to install additional firmware and modules"
echo "Doing depmod for ordinary kernel"
cd /lib/modules/${KERNEL}+
depmod
echo "Doing depmod for v7 kernel"
cd /lib/modules/${KERNEL}-v7+
depmod

echo "configuring unconfigured packages"
dpkg --configure --pending

echo "Creating /var/log/samba folder"
[ -d /var/log/samba ] || mkdir /var/log/samba

echo "Removing default SSH host keys"
# These should be created on first boot to ensure they are unique on each system
rm -v /etc/ssh/ssh_host_*

echo "Generating SSH host keys"
dpkg-reconfigure openssh-server

echo "Disabling firststart service"
systemctl disable firststart.service

echo "Finalizing"
sync
