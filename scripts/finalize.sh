#!/bin/sh

echo "Computing Volumio folder Hash Checksum"
HASH=`/usr/bin/md5deep -r -l -s -q /mnt/volumio/rootfs/volumio | sort | md5sum | tr -d "-" | tr -d " \t\n\r"`
echo "VOLUMIO_HASH=\"${HASH}\"" >> /mnt/volumio/rootfs/etc/os-release

echo "Cleanup to save space"
find /mnt/volumio/rootfs/usr/share/doc -depth -type f ! -name copyright|xargs rm || true
find /mnt/volumio/rootfs/usr/share/doc -empty|xargs rmdir || true
rm -rf /mnt/volumio/rootfs/usr/share/man/* /mnt/volumio/rootfs/usr/share/groff/* /mnt/volumio/rootfs/usr/share/info/*
rm -rf /mnt/volumio/rootfs/usr/share/lintian/* /mnt/volumio/rootfs/usr/share/linda/* /mnt/volumio/rootfs/var/cache/man/*
