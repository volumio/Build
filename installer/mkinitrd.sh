#!/bin/bash

source /config.sh

if [ ! "x${PACKAGES}" == "x" ]; then
   echo "[info] Adding board-specific packages"
   apt-get update
   apt-get install -y "${PACKAGES}"
fi

echo "[info] Adding custom modules"
echo "" > /etc/initramfs-tools/modules
for module in ${MODULES}
do 
   echo $module >> /etc/initramfs-tools/modules
done

echo "[info] Changing to 'modules=list'"
sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf

echo "Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp



