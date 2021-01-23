#!/bin/bash

set -eo pipefail

# HARDWARE=`/bin/cat /mnt/volumio/rootfs/etc/os-release | grep "VOLUMIO_HARDWARE" | cut -d \\" -f2 | tr -d "\n"`

[ -z "${ROOTFSMNT}" ] && ROOTFSMNT=/mnt/volumio/rootfs
log "Computing Volumio folder Hash Checksum" "info"

HASH="$(md5deep -r -l -s -q ${ROOTFSMNT}/volumio | sort | md5sum | awk '{print $1}')"
log "HASH: ${HASH}" "dbg"
cat <<-EOF >>${ROOTFSMNT}/etc/os-release
VOLUMIO_HASH="${HASH}"
EOF
# base-files updates can overwrite our custom info.
log "Checking os-release"
if ! grep "VOLUMIO_HARDWARE" ${ROOTFSMNT}/etc/os-release; then
  log "Missing VOLUMIO_ info in /etc/os-release!" "err"
  cat ${ROOTFSMNT}/etc/os-release
  exit 10 # Bail!
fi
log "Cleaning rootfs to save space" "info"
# Remove our apt cache proxy
[[ -e "${ROOTFSMNT}/etc/apt/apt.conf.d/02cache" ]] && rm "${ROOTFSMNT}/etc/apt/apt.conf.d/02cache"

log "Cleaning docs"
log "Pre /usr/share/" "$(du -sh0 /usr/share | cut -f1)"
share_dirs=("doc" "locale" "man")
declare -A pre_size
for path in "${share_dirs[@]}"; do
  pre_size["${path}"]="$(du -sh0 "/usr/share/${path}" | cut -f1)"
done

find ${ROOTFSMNT}/usr/share/doc -depth -type f ! -name copyright -delete # Remove docs that aren't copyrights
find ${ROOTFSMNT}/usr/share/doc -empty -delete                           # Empty files
find ${ROOTFSMNT}/usr/share/doc -type l -delete                          # Remove missing symlinks

# if [[ ${BUILD:0:3} == arm ]]; then
log "Cleaning man and caches"
rm -rf ${ROOTFSMNT}/usr/share/man/* ${ROOTFSMNT}/usr/share/groff/* ${ROOTFSMNT}/usr/share/info/*
rm -rf ${ROOTFSMNT}/usr/share/lintian/* ${ROOTFSMNT}/usr/share/linda/* ${ROOTFSMNT}/var/cache/man/*

log "Final /usr/share/" "$(du -sh /usr/share | cut -f1)"
for path in "${share_dirs[@]}"; do
  log "${path}:" "Pre: ${pre_size[$path]} Post: $(du -sh "/usr/share/${path}" | cut -f1)"
done

#TODO: This doesn't seem to be doing much atm
log "Stripping binaries"
STRP_DIRECTORIES=("${ROOTFSMNT}/lib/"
  "${ROOTFSMNT}/bin/"
  "${ROOTFSMNT}/usr/sbin"
  "${ROOTFSMNT}/usr/local/bin/"
  "${ROOTFSMNT}/lib/modules/")

for DIR in "${STRP_DIRECTORIES[@]}"; do
  log "$DIR Pre  size" "$(du -sh0 "$DIR" | cut -f1)"
  find "$DIR" -type f -exec strip --strip-unneeded {} ';' >/dev/null 2>&1
  log "$DIR Post size" "$(du -sh0 "$DIR" | cut -f1)"
done
# else
#   log "${BUILD} environment detected, not cleaning/stripping libs"
# fi

log "Checking rootfs size"
rootfs_size=$(du -hsx --exclude=/{proc,sys,dev} "${ROOTFSMNT}")
volumio_size=$(du -hsx ${ROOTFSMNT}/{volumio,myvolumio})
log "Complete rootfs: " "${rootfs_size}"
log "Volumio  parts: " "${volumio_size}"

# Got to do this here to make it stick
log "Updating MOTD"
rm -f ${ROOTFSMNT}/etc/motd ${ROOTFSMNT}/etc/update-motd.d/*
cp "${SRC}"/volumio/etc/update-motd.d/* ${ROOTFSMNT}/etc/update-motd.d/

log "Add Volumio WebUI IP"
cat <<-EOF >>${ROOTFSMNT}/etc/issue
Welcome to Volumio!
WebUI available at \n.local (\4)
EOF
