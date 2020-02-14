#!/bin/bash

set -eo pipefail

# This script will be run in chroot under qemu.
# Re import helpers in chroot
# shellcheck source=./scripts/helpers.sh
source /helpers.sh
export -f log
export -f time_it

function exit_error()
{
  log "Volumio chroot config failed" "$(basename "$0")" "err"
}

trap exit_error INT ERR

log "Getting UUIDS"
source init.sh
log "/dev/mmcblk0p1 : uudi: ${UUID_BOOT}"
log "/dev/mmcblk0p2 : uudi: ${UUID_IMG}"
log "/dev/mmcblk0p3 : uudi: ${UUID_DATA}"

log "Creating fstab" "info"
cat <<-EOF > /etc/fstab
# ROCK Pi S fstab

proc           /proc                proc    defaults                                  0 0
/dev/mmcblk0p1 /boot                vfat    defaults,utf8,user,rw,umask=111,dmask=000 0 1
tmpfs          /var/log             tmpfs   size=20M,nodev,uid=1000,mode=0777,gid=4,  0 0
tmpfs          /var/spool/cups      tmpfs   defaults,noatime,mode=0755                0 0
tmpfs          /var/spool/cups/tmp  tmpfs   defaults,noatime,mode=0755                0 0
tmpfs          /tmp                 tmpfs   defaults,noatime,mode=0755                0 0
tmpfs          /dev/shm             tmpfs   defaults,nosuid,noexec,nodev              0 0
EOF

# CONFIG_NLS_CODEPAGE_437: Codepage 437
log "Adding custom modules overlayfs, squashfs and nls_cp437"
cat <<-EOF >> /etc/initramfs-tools/modules
overlay
overlayfs
squashfs
nls_cp437
EOF

if [[ -f /root/volumio-init-updater ]]; then
  log "Copying volumio initramfs updater"
  mv /root/volumio-init-updater /usr/local/sbin
fi

#On The Fly Patch
PATCH=$(cat /patch)
if [ "$PATCH" = "volumio" ]; then
  log "No Patch To Apply" "wrn"
else
  log "Applying Patch ${PATCH}" "wrn"
  PATCHPATH=/${PATCH}
  cd $PATCHPATH || exit
  #Check the existence of patch script
  if [ -f "patch.sh" ]; then
    sh patch.sh
  else
    log "Cannot Find Patch File, aborting" "err"
  fi
  cd /
  rm -rf ${PATCH}
fi

log "Installing winbind here, since it freezes networking" "info"
apt-get update
apt-get install -y winbind libnss-winbind u-boot-tools

log "adding gpio group and udev rules" "info"
groupadd -f --system gpio
usermod -aG gpio volumio
touch /etc/udev/rules.d/99-gpio.rules
echo "SUBSYSTEM==\"gpio\", ACTION==\"add\", RUN=\"/bin/sh -c '
        chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio;\
        chown -R root:gpio /sys$DEVPATH && chmod -R 770 /sys$DEVPATH\
  '\"" > /etc/udev/rules.d/99-gpio.rules

log "Cleaning APT Cache and remove policy file" "info"
rm -f /var/lib/apt/lists/*archive*
apt-get clean
rm /usr/sbin/policy-rc.d

#First Boot operations
log "Signalling the init script to re-size the volumio data partition"
touch /boot/resize-volumio-datapart

log "Creating initramfs 'volumio.initrd'" "info"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp

log "Finished creating initramfs" "okay"

log "Creating uInitrd from 'volumio.initrd'" "info"
mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d /boot/volumio.initrd /boot/uInitrd
mkimage -A arm -T script -C none -d /boot/boot.cmd /boot/boot.scr
