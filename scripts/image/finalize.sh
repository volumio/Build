#!/usr/bin/env bash

set -eo pipefail

log "Computing Volumio folder Hash Checksum" "info"

HASH="$(md5deep -r -l -s -q "${ROOTFSMNT}"/volumio | sort | md5sum | awk '{print $1}')"
log "HASH: ${HASH}" "dbg"
cat <<-EOF >>"${ROOTFSMNT}"/etc/os-release
VOLUMIO_HASH="${HASH}"
EOF
# base-files updates can overwrite our custom info.
log "Checking os-release"
if ! grep "VOLUMIO_HARDWARE" "${ROOTFSMNT}"/etc/os-release; then
  log "Missing VOLUMIO_ info in /etc/os-release!" "err"
  cat "${ROOTFSMNT}"/etc/os-release
  exit 10 # Bail!
fi
log "Cleaning rootfs to save space" "info"
# Remove our apt cache proxy
[[ -e "${ROOTFSMNT}/etc/apt/apt.conf.d/02cache" ]] && rm "${ROOTFSMNT}/etc/apt/apt.conf.d/02cache"

log "Cleaning docs"
log "Pre /usr/share/" "$(check_size /usr/share)"
share_dirs=("doc" "locale" "man")
declare -A pre_size
for path in "${share_dirs[@]}"; do
  pre_size["${path}"]=$(check_size "/usr/share/${path}")
done

find "${ROOTFSMNT}"/usr/share/doc -depth -type f ! -name copyright -delete # Remove docs that aren't copyrights
find "${ROOTFSMNT}"/usr/share/doc -empty -delete                           # Empty files
find "${ROOTFSMNT}"/usr/share/doc -type l -delete                          # Remove missing symlinks

# if [[ ${BUILD:0:3} == arm ]]; then
log "Cleaning man and caches"
rm -rf "${ROOTFSMNT}"/usr/share/man/* "${ROOTFSMNT}"/usr/share/groff/* "${ROOTFSMNT}"/usr/share/info/*
rm -rf "${ROOTFSMNT}"/usr/share/lintian/* "${ROOTFSMNT}"/usr/share/linda/* "${ROOTFSMNT}"/var/cache/man/*

rm -rf "${ROOTFSMNT}"/var/lib/apt/lists/*
rm -rf "${ROOTFSMNT}"/var/cache/apt/*

log "Final /usr/share/" "$(check_size /usr/share)"
for path in "${share_dirs[@]}"; do
  log "${path}:" "Pre: ${pre_size[$path]} Post: $(check_size "/usr/share/${path}")"
done

#TODO: This doesn't seem to be doing much atm
log "Stripping binaries"
STRP_DIRECTORIES=("${ROOTFSMNT}/lib/"
  "${ROOTFSMNT}/bin/"
  "${ROOTFSMNT}/usr/sbin"
  "${ROOTFSMNT}/usr/local/bin/"
  "${ROOTFSMNT}/lib/modules/")

for DIR in "${STRP_DIRECTORIES[@]}"; do
  log "${DIR} Pre  size" "$(check_size "${DIR}")"
  find "${DIR}" -type f -exec strip --strip-unneeded {} ';' >/dev/null 2>&1
  log "${DIR} Post size" "$(check_size "${DIR}")"
done
# else
#   log "${BUILD} environment detected, not cleaning/stripping libs"
# fi

log "Checking rootfs size"
log "Rootfs:" "$(check_size "${ROOTFSMNT}")"
log "Volumio parts:" "$(check_size "${ROOTFSMNT}"/volumio) $(check_size "${ROOTFSMNT}"/myvolumio)"

# Got to do this here to make it stick
log "Updating MOTD"
rm -f "${ROOTFSMNT}"/etc/motd "${ROOTFSMNT}"/etc/update-motd.d/*
cp "${SRC}"/volumio/etc/update-motd.d/* "${ROOTFSMNT}"/etc/update-motd.d/

#TODO This shall be refactored as per https://github.com/volumio/Build/issues/479
# Temporary workaround
log "Copying over upmpdcli.service"
cp "${SRC}/volumio/lib/systemd/system/upmpdcli.service" "${ROOTFSMNT}/lib/systemd/system/upmpdcli.service"

log "Copying over shairport-sync.service"
[[ -e "${ROOTFSMNT}/lib/systemd/system/shairport-sync.service" ]] && rm "${ROOTFSMNT}/lib/systemd/system/shairport-sync.service"
cp "${SRC}/volumio/lib/systemd/system/shairport-sync.service" "${ROOTFSMNT}/lib/systemd/system/shairport-sync.service"

log "Add Volumio WebUI IP"
cat <<-EOF >>"${ROOTFSMNT}"/etc/issue
Welcome to Volumio!
WebUI available at \n.local (\4)
EOF
