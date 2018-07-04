#!/bin/sh

echo "Computing Volumio folder Hash Checksum"
HASH=`/usr/bin/md5deep -r -l -s -q /mnt/volumio/rootfs/volumio | sort | md5sum | tr -d "-" | tr -d " \t\n\r"`
echo "VOLUMIO_HASH=\"${HASH}\"" >> /mnt/volumio/rootfs/etc/os-release

