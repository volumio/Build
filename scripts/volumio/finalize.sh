#!/bin/bash

set -eo pipefail

# HARDWARE=`/bin/cat /mnt/volumio/rootfs/etc/os-release | grep "VOLUMIO_HARDWARE" | cut -d \\" -f2 | tr -d "\n"`

[ -z $ROOTFSMNT ] && ROOTFSMNT=/mnt/volumio/rootfs
log "Computing Volumio folder Hash Checksum" "info"

HASH="$(md5deep -r -l -s -q ${ROOTFSMNT}/volumio | sort | md5sum | awk '{print $1}')"
log "HASH: ${HASH}" "dbg"
# HASH=`/usr/bin/md5deep -r -l -s -q ${ROOTFSMNT}/volumio | sort | md5sum | tr -d "-" | tr -d " \t\n\r"`
cat <<-EOF >> ${ROOTFSMNT}/etc/os-release
VOLUMIO_HASH="${HASH}"
EOF

log "Cleaning stuff to save space" "info"
log "Cleaning docs"
find ${ROOTFSMNT}/usr/share/doc -depth -type f ! -name copyright -delete #| xargs rm
find ${ROOTFSMNT}/usr/share/doc -empty -delete #|xargs rmdir || true

if [[ $BUILD != "x86" ]]; then
  log "Cleaning man and caches"
  rm -rf ${ROOTFSMNT}/usr/share/man/* ${ROOTFSMNT}/usr/share/groff/* ${ROOTFSMNT}/usr/share/info/*
  rm -rf ${ROOTFSMNT}/usr/share/lintian/* ${ROOTFSMNT}/usr/share/linda/* ${ROOTFSMNT}/var/cache/man/*

else
  echo "X86 Environmant detected, not cleaning"
fi

#TODO: This doesn't seem to be doing much atm
log "Stripping binaries"
STRP_DIRECTORIES=("${ROOTFSMNT}/lib/" \
                  "${ROOTFSMNT}/bin/" \
                  "${ROOTFSMNT}/usr/sbin" \
                  "${ROOTFSMNT}/usr/local/bin/")

for DIR in "${STRP_DIRECTORIES[@]}"; do
  log "$DIR Pre strip size " "$(du -sh0 "$DIR" | awk '{print $1}')"
  find "$DIR" -type f  -exec strip --strip-all {} ';' > /dev/null 2>&1
  log "$DIR Post strip size " "$(du -sh0 "$DIR" | awk '{print $1}')"
done
