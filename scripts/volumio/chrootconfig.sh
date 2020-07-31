#!/bin/bash

set -eo pipefail

# This script will be run in chroot under qemu.
# Re import helpers in chroot
# shellcheck source=./scripts/helpers.sh
source /helpers.sh
CHROOT=yes
export CHROOT
export -f log
export -f time_it

# shellcheck source=/dev/null
source /chroot_device_config.sh

function exit_error()
{
  log "Volumio chroot config failed" "$(basename "$0")" "err"
}

trap exit_error INT ERR

log "Running final config for ${DEVICENAME}"

## Setup Fstab
log "Creating fstab" "info"
cat <<-EOF > /etc/fstab
# ${DEVICENAME} fstab

proc           /proc                proc    defaults                                  0 0
/dev/mmcblk0p1 /boot                vfat    defaults,utf8,user,rw,umask=111,dmask=000 0 1
tmpfs          /var/log             tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4,  0 0
tmpfs          /var/spool/cups      tmpfs   defaults,noatime,mode=0755                0 0
tmpfs          /var/spool/cups/tmp  tmpfs   defaults,noatime,mode=0755                0 0
tmpfs          /tmp                 tmpfs   defaults,noatime,mode=0755                0 0
tmpfs          /dev/shm             tmpfs   defaults,nosuid,noexec,nodev              0 0
EOF

## Initial chroot config
declare -fF device_chroot_tweaks &>/dev/null \
  && log "Entering device_chroot_tweaks" "cfg" \
  && device_chroot_tweaks

## Activate modules
# shellcheck disable=SC2116
log "Activating ${#MODULES[@]} custom modules:" "" "$(echo "${MODULES[@]}")"
mod_list=$(printf "%s\n"  "${MODULES[@]}")
cat <<-EOF >> /etc/initramfs-tools/modules
# Volumio modules
${mod_list}
EOF

#On The Fly Patch
#TODO Where should this be called?
PATCH=$(cat /patch)
if [ "$PATCH" = "volumio" ]; then
  log "No Patch To Apply" "wrn"
else
  log "Applying Patch ${PATCH}" "wrn"
  PATCHPATH=/"${PATCH}"
  cd "${PATCHPATH}" || exit
  #Check the existence of patch script
  if [ -f "patch.sh" ]; then
    sh patch.sh
  else
    log "Cannot Find Patch File, aborting" "err"
  fi
  if [ -f "install.sh" ]; then
    log "Running install.sh" "ext" "${PATCH}"
    bash install.sh
  fi
  cd /
  rm -rf "${PATCH}" /patch
  log "Finished on the fly patching" "ok"
fi

## Adding board specific packages
# shellcheck disable=SC2116
log "Installing ${#PACKAGES[@]} custom packages:" "" "$(echo "${PACKAGES[@]}")"
apt-get update
apt-get install -y "${PACKAGES[@]}"

# Custom packages for Volumio
[ -f "/install-kiosk.sh" ] && bash install-kiosk.sh
if [ -d "/volumio/customPkgs/" ]; then
  log "Installing Volumio customPkgs" "info"
  for deb in /volumio/customPkgs/*.deb; do
    log "Installing ${deb}"
    dpkg -i "${deb}"
  done
fi

log "Entering device_chroot_tweaks_pre" "cfg"
device_chroot_tweaks_pre

log "Cleaning APT Cache and remove policy file" "info"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d
rm -r /volumio/customPkgs

# Fix services for tmpfs logs
log "Ensuring /var/log has right folders and permissions"
sed -i '/^ExecStart=.*/i ExecStartPre=touch /var/log/mpd.log' /lib/systemd/system/mpd.service
sed -i '/^ExecStart=.*/i ExecStartPre=chown volumio /var/log/mpd.log' /lib/systemd/system/mpd.service
sed -i '/^ExecStart=.*/i ExecStartPre=mkdir -m 700 -p /var/log/samba/cores' /lib/systemd/system/nmbd.service
# sed -i '/^ExecStart=.*/i ExecStartPre=chmod 700 /var/log/samba/cores' /lib/systemd/system/nmbd.service

#First Boot operations
log "Signalling the init script to re-size the Volumio data partition"
touch /boot/resize-volumio-datapart

log "Creating initramfs 'volumio.initrd'" "info"
mkinitramfs-buster.sh -o /tmp/initramfs-tmp
log "Finished creating initramfs" "okay"

log "Entering device_chroot_tweaks_post" "cfg"
device_chroot_tweaks_post
