#!/bin/bash

source /config.sh

if [ ! "x${PACKAGES}" == "x" ]; then
   echo "[info] Adding board-specific packages"
   apt-get update
   apt-get install -y "${PACKAGES[@]}"
fi

echo "[info] Adding custom modules"
mod_list=$(printf "%s\n"  "${MODULES[@]}")
cat <<-EOF >> /etc/initramfs-tools/modules
# Volumio modules
${mod_list}
EOF

echo "[info] Changing to 'modules=list'"
sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf

echo "Creating initramfs 'volumio.initrd'"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp



