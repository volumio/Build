#!/bin/bash

echo "Volumio first start configuration script"

echo "configuring unconfigured packages"
dpkg --configure --pending

echo "Creating /var/log/samba/cores folder"
mkdir -p /var/log/samba/cores && chmod -R 0700 "$_"

echo "Creating /boot/userconfig.txt"
echo "# Add your custom config.txt options to this file, which will be preserved during updates" >> /boot/userconfig.txt

echo "Removing default SSH host keys"
# These should be created on first boot to ensure they are unique on each system
rm -v /etc/ssh/ssh_host_*

echo "Generating SSH host keys"
dpkg-reconfigure openssh-server

echo "Enabling SSH for first boot"
systemctl start ssh.service

echo "Disabling firststart service"
systemctl disable firststart.service

echo "Finalizing"
sync
