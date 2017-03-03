#!/bin/bash

echo "Volumio first start configuration script"

echo "configuring unconfigured packages"
dpkg --configure --pending

echo "Creating /var/log/samba folder"
mkdir /var/log/samba

echo "Removing default SSH host keys"
# These should be created on first boot to ensure they are unique on each system
rm -v /etc/ssh/ssh_host_*

echo "Generating SSH host keys"
dpkg-reconfigure openssh-server

echo "Disabling firststart service"
systemctl disable firststart.service

echo "Finalizing"
sync
