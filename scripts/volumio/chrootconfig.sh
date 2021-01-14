#!/bin/bash

set -eo pipefail
set -o errtrace
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

function exit_error() {
  log "Volumio chroot config failed" "err" "$(basename "$0")"
  log "Error stack $(printf '[%s] <= ' "${FUNCNAME[@]:1}")" "err" "$(caller)"
}

trap exit_error INT ERR

log "Running final config for ${DEVICENAME}"

## Setup Fstab
log "Creating fstab" "info"
cat <<-EOF >/etc/fstab
# ${DEVICENAME} fstab

proc            /proc                proc    defaults                                  0 0
${BOOT_FS_SPEC} /boot                vfat    defaults,utf8,user,rw,umask=111,dmask=000 0 1
tmpfs           /var/log             tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4,  0 0
tmpfs           /var/spool/cups      tmpfs   defaults,noatime,mode=0755                0 0
tmpfs           /var/spool/cups/tmp  tmpfs   defaults,noatime,mode=0755                0 0
tmpfs           /tmp                 tmpfs   defaults,noatime,mode=0755                0 0
tmpfs           /dev/shm             tmpfs   defaults,nosuid,noexec,nodev              0 0
EOF

## Initial chroot config
declare -fF device_chroot_tweaks &>/dev/null &&
  log "Entering device_chroot_tweaks" "cfg" &&
  device_chroot_tweaks

log "Continuing chroot config" "info"
## Activate modules
log "Activating ${#MODULES[@]} custom modules:" "" "${MODULES[*]}"
mod_list=$(printf "%s\n" "${MODULES[@]}")
cat <<-EOF >>/etc/initramfs-tools/modules
# Volumio modules
${mod_list}
EOF

## Adding board specific packages
log "Installing ${#PACKAGES[@]} custom packages:" "" "${PACKAGES[*]}"
apt-get update
apt-get install -y "${PACKAGES[@]}"

# Custom packages for Volumio
#TODO THIS SHALL RUN ONLY FOR SOME DEVICES WHERE WE WANT TO INSTALL KIOSK
[ -f "/install-kiosk.sh" ] && log "Installing kiosk" "info" && bash install-kiosk.sh
if [[ -d "/volumio/customPkgs" ]] && [[ $(ls /volumio/customPkgs/*.deb 2> /dev/null) ]]; then
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
# rm /usr/sbin/policy-rc.d
[[ -d /volumio/customPkgs ]] && rm -r "/volumio/customPkgs"
[[ -f /install-kiosk.sh ]] && rm "/install-kiosk.sh"

# Fix services for tmpfs logs
log "Ensuring /var/log has right folders and permissions"
sed -i '/^ExecStart=.*/i ExecStartPre=touch /var/log/mpd.log' /lib/systemd/system/mpd.service
sed -i '/^ExecStart=.*/i ExecStartPre=chown volumio /var/log/mpd.log' /lib/systemd/system/mpd.service
sed -i '/^ExecStart=.*/i ExecStartPre=mkdir -m 700 -p /var/log/samba/cores' /lib/systemd/system/nmbd.service
# sed -i '/^ExecStart=.*/i ExecStartPre=chmod 700 /var/log/samba/cores' /lib/systemd/system/nmbd.service

# Fix for https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=934540
# that will not make it into buster
log "Applying buster specific {n,s}mpd.service PID tweaks"
sed -i 's|^PIDFile=/var/run/samba/smbd.pid|PIDFile=/run/samba/smbd.pid|' /lib/systemd/system/smbd.service
sed -i 's|^PIDFile=/var/run/samba/nmbd.pid|PIDFile=/run/samba/nmbd.pid|' /lib/systemd/system/nmbd.service

#First Boot operations
log "Signalling the init script to re-size the Volumio data partition"
touch /boot/resize-volumio-datapart

#On The Fly Patch
#TODO Where should this be called?
PATCH=$(cat /patch)
if [ "$PATCH" = "volumio" ]; then
  log "No Patch To Apply" "wrn"
  rm /patch
else
  log "Applying Patch ${PATCH}" "wrn"
  #Check the existence of patch script(s)
  patch_scrips=("patch.sh" "install.sh")
  if [[ -d ${PATCH} ]]; then
    pushd "${PATCH}"
    for script in "${patch_scrips[@]}"; do
      log "Running ${script}" "ext" "${PATCH}"
      bash "${script}"
      status=$?
      [[ ${status} -ne 0 ]] && log "${script} failed with ${status}" "err" "${PATCH}"
    done
    popd
  else
    log "Cannot Find Patch, aborting" "err"
  fi
  log "Finished on the fly patching" "ok"
  rm -rf "${PATCH}" /patch
fi

# #mke2fsfull is used since busybox mke2fs does not include ext4 support
cp -rp /sbin/mke2fs /sbin/mke2fsfull

log "Creating initramfs 'volumio.initrd'" "info"
mkinitramfs-buster.sh -o /tmp/initramfs-tmp
log "Finished creating initramfs" "okay"

log "Entering device_chroot_tweaks_post" "cfg"
device_chroot_tweaks_post

# Check permissions again
log "Checking dir owners again"
voldirs=("/volumio" "/myvolumio")
for dir in "${voldirs[@]}"; do
  [[ ! -d ${dir} ]] && continue
  voldirperms=$(stat -c '%U:%G' "${dir}")
  log "${dir} -- ${voldirperms}"
  if [[ ${voldirperms} != "volumio:volumio" ]]; then
    log "Fixing dir perms for ${dir}"
    chown -R volumio:volumio "${dir}"
  fi
done
