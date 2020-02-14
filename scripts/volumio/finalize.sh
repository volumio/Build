#!/bin/bash

HARDWARE=`/bin/cat /mnt/volumio/rootfs/etc/os-release | grep "VOLUMIO_HARDWARE" | cut -d \\" -f2 | tr -d "\n"`
BASEDIR=/mnt/volumio/rootfs
log "Computing Volumio folder Hash Checksum" "info"
HASH=`/usr/bin/md5deep -r -l -s -q /mnt/volumio/rootfs/volumio | sort | md5sum | tr -d "-" | tr -d " \t\n\r"`
log "VOLUMIO_HASH=\"${HASH}\"" >> /mnt/volumio/rootfs/etc/os-release

log "Cleanup to save space" "info"

log "Cleaning docs"
find /mnt/volumio/rootfs/usr/share/doc -depth -type f ! -name copyright|xargs rm || true
find /mnt/volumio/rootfs/usr/share/doc -empty|xargs rmdir || true

if [ $HARDWARE != "x86" ]; then

log "Cleaning man and caches"
rm -rf /mnt/volumio/rootfs/usr/share/man/* /mnt/volumio/rootfs/usr/share/groff/* /mnt/volumio/rootfs/usr/share/info/*
rm -rf /mnt/volumio/rootfs/usr/share/lintian/* /mnt/volumio/rootfs/usr/share/linda/* /mnt/volumio/rootfs/var/cache/man/*

log "Stripping binaries"


STRP_DIRECTORIES=("$BASEDIR/lib/" "$BASEDIR/bin/" "$BASEDIR/usr/sbin" "$BASEDIR/usr/local/bin/")
for DIR in "${STRP_DIRECTORIES[@]}"; do
 log "$DIR Pre strip size " "$(du -sh0 "$DIR" | awk '{print $1}')"
 find "$DIR" -type f  -exec strip --strip-all > /dev/null 2>&1 {} ';'
 log "$DIR Post strip size " "$(du -sh0 "$DIR" | awk '{print $1}')"
done


find $BASEDIR/lib/ -type f  -exec strip --strip-all > /dev/null 2>&1 {} ';'
find $BASEDIR/bin/ -type f  -exec strip --strip-all > /dev/null 2>&1 {} ';'
find $BASEDIR/usr/sbin -type f  -exec strip --strip-all > /dev/null 2>&1 {} ';'
find $BASEDIR/usr/local/bin/ -type f  -exec strip --strip-all > /dev/null 2>&1 {} ';'

else
  echo "X86 Environmant detected, not cleaning"
  find $BASEDIR/bin/ -type f  -exec strip --strip-all > /dev/null 2>&1 {} ';'
find $BASEDIR/usr/sbin -type f  -exec strip --strip-all > /dev/null 2>&1 {} ';'
find $BASEDIR/usr/local/bin/ -type f  -exec strip --strip-all > /dev/null 2>&1 {} ';'


fi
