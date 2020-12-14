#!/bin/bash
##
#Volumio system Configuration Script
##

set -eo pipefail
function exit_error() {
  log "Volumio config failed" "err" "$(basename "$0")"
}

trap exit_error INT ERR

log "Copying Custom Volumio System Files" "info"

# Apt sources
log "Copying Apt lists" "sources.list.${BUILD}"
cp "${SRC}"/volumio/etc/apt/sources.list."${BUILD}" "${ROOTFS}/etc/apt/sources.list"
if [[ $BUILD == x86 ]]; then
  log 'Copying X86 related Configuration files'
  #Grub2 conf file
  cp "${SRC}/volumio/etc/default/grub" "${ROOTFS}/etc/default/grub"
  cp "${SRC}/volumio/splash/volumio.png" "${ROOTFS}/boot"
  #FSTAB File
  cp "${SRC}/volumio/etc/fstab.x86" "${ROOTFS}/etc/fstab"
else
  log 'Setting time for ARM devices with fakehwclock to build time'
  date -u '+%Y-%m-%d %H:%M:%S' >"${ROOTFS}/etc/fake-hwclock.data"
fi

log "Copying misc config/tweaks to rootfs" "info"

if [[ $SUITE == "buster" ]]; then
  log "Enabling buster specific tweaks" "info"
  log "Updating Backend .env"
  sed -i 's/^NODE_MOUNT_HANDLER=false/NODE_MOUNT_HANDLER=true/' "${ROOTFS}/volumio/.env"
  log "Confirm if following tweaks are still required for Debain - $SUITE" "wrn"
fi

# TODO: Streamline this!!
# map files from ${SRC}/volumio => ${ROOTFS}?
#

#Edimax Power Saving Fix + Alsa modprobe
cp -r "${SRC}/volumio/etc/modprobe.d" "${ROOTFS}/etc/"

#Hosts file
cp -p "${SRC}/volumio/etc/hosts" "${ROOTFS}/etc/hosts"

#Samba conf file
cp "${SRC}/volumio/etc/samba/smb.conf" "${ROOTFS}/etc/samba/smb.conf"

#Udev confs file (NET)
cp -r "${SRC}/volumio/etc/udev" "${ROOTFS}/etc/"

#Polkit for USB mounts
cp -r "${SRC}/volumio/etc/polkit-1/localauthority/50-local.d/50-mount-as-pi.pkla" \
  "${ROOTFS}/etc/polkit-1/localauthority/50-local.d/50-mount-as-pi.pkla"

#Inittab file
cp "${SRC}/volumio/etc/inittab" "${ROOTFS}/etc/inittab"

#MOTD
# Seems to get overwritten later
# rm -f "${ROOTFSMNT}/etc/motd" "${ROOTFSMNT}"/etc/update-motd.d/*
# cp "${SRC}"/volumio/etc/update-motd.d/* "${ROOTFS}/etc/update-motd.d/"

#SSH
cp "${SRC}/volumio/etc/ssh/sshd_config" "${ROOTFS}/etc/ssh/sshd_config"

#Mpd
cp "${SRC}/volumio/etc/mpd.conf" "${ROOTFS}/etc/mpd.conf"
chmod 777 "${ROOTFS}/etc/mpd.conf"

#Log via JournalD in RAM
cp "${SRC}/volumio/etc/systemd/journald.conf" "${ROOTFS}/etc/systemd/journald.conf"

#Volumio SystemD Services
cp -r "${SRC}"/volumio/lib "${ROOTFS}"/


# Network
cp -r "${SRC}"/volumio/etc/network/* "${ROOTFS}"/etc/network

# Wpa Supplicant
echo " " >"${ROOTFS}"/etc/wpa_supplicant/wpa_supplicant.conf
chmod 777 "${ROOTFS}"/etc/wpa_supplicant/wpa_supplicant.conf

#Shairport
cp "${SRC}/volumio/etc/shairport-sync.conf" "${ROOTFS}/etc/shairport-sync.conf"
chmod 777 "${ROOTFS}/etc/shairport-sync.conf"

#nsswitch
cp "${SRC}/volumio/etc/nsswitch.conf" "${ROOTFS}/etc/nsswitch.conf"

#firststart
cp "${SRC}/volumio/bin/firststart.sh" "${ROOTFS}/bin/firststart.sh"

#dynswap
cp "${SRC}/volumio/bin/dynswap.sh" "${ROOTFS}/bin/dynswap.sh"

#Wireless
cp "${SRC}/volumio/bin/wireless.js" "${ROOTFS}/volumio/app/plugins/system_controller/network/wireless.js"

#udev script
cp "${SRC}/volumio/bin/rename_netiface0.sh" "${ROOTFS}/bin/rename_netiface0.sh"
chmod a+x "${ROOTFS}/bin/rename_netiface0.sh"

#Plymouth & upmpdcli files
cp -rp "${SRC}"/volumio/usr/* "${ROOTFS}/usr/"

#CPU TWEAK
cp "${SRC}/volumio/bin/volumio_cpu_tweak" "${ROOTFS}/bin/volumio_cpu_tweak"
chmod a+x "${ROOTFS}/bin/volumio_cpu_tweak"

#LAN HOTPLUG
cp "${SRC}/volumio/etc/default/ifplugd" "${ROOTFS}/etc/default/ifplugd"

log 'Done Copying Custom Volumio System Files' "okay"
