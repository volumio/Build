#!/bin/sh

echo "Computing Volumio folder Hash Checksum"
HASH=`/usr/bin/find /volumio -type f | sort -u | xargs cat | md5sum | tr -d "-" | tr -d " \t\n\r"`
echo "VOLUMIO_HASH=${HASH}" >> /mnt/volumio/rootfs/etc/os-release

