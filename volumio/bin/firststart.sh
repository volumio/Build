#!/bin/bash

echo "Volumio first start configuration script"

echo "configuring unconfigured packages"
dpkg --configure --pending

echo "Installing winbind, its done here because else it will freeze networking"

[ -d /var/log/samba ] || mkdir /var/log/samba
cd /
dpkg -i libnss-winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb
dpkg -i winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb
rm /libnss-winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb
rm /winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb

echo "Removing default SSH host keys"
# These should be created on first boot to ensure they are unique on each system
rm -v /etc/ssh/ssh_host_*

echo "Generating SSH host keys"
dpkg-reconfigure openssh-server

echo "Disabling firststart service"
systemctl disable firststart.service

echo "Finalizing"
sync
