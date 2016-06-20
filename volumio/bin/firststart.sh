#!/bin/bash

echo "Volumio first start configuration script"

echo "configuring unconfigured packages"
dpkg --configure --pending

echo "Installing winbind, its done here because else it will freeze networking"

mkdir /var/log/samba
cd /
wget http://repo.volumio.org/Volumio2/Binaries/arm/libnss-winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb
wget http://repo.volumio.org/Volumio2/Binaries/arm/winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb
dpkg -i libnss-winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb
dpkg -i winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb
rm /libnss-winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb
rm /winbind_23a4.2.10+dfsg-0+deb8u3_armhf.deb

echo "Disabling firststart service"
systemctl disable firststart.service
