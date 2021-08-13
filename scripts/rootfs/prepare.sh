#!/usr/bin/env bash
# Prepare rootfs prior to chroot config

set -eo pipefail
function exit_error() {
	log "Volumio config failed" "err" "echo ""${1}" "$(basename "$0")"""
}

trap 'exit_error ${LINENO}' INT ERR

log "Preparing for chroot configuration" "info"

# Apt sources
log "Creating Apt lists for ${BASE}"
AptComponents=("main" "contrib" "non-free")
[[ ${BASE} == "Raspbian" ]] && AptComponents+=("rpi")
log "Setting repo to ${APTSOURCE[${BASE}]} ${SUITE} ${AptComponents[*]}"
cat <<-EOF >"${ROOTFS}/etc/apt/sources.list"
	deb ${APTSOURCE[${BASE}]} ${SUITE} ${AptComponents[*]}
	# Uncomment line below then 'apt-get update' to enable 'apt-get source'
	#deb-src ${APTSOURCE[${BASE}]} ${SUITE} ${AptComponents[*]}
EOF
