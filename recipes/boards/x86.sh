#!/usr/bin/env bash
# shellcheck disable=SC2034
## Setup for x86 devices

## WIP: this should be refactored out to a higher level
# Aka base config for arm,armv7,armv8 and x86
# Base system
BASE="Debian"
ARCH="i386"
BUILD="x86"

DEBUG_BUILD=no
### Device information
DEVICENAME="x86"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEBASE="x86"

# Disable to ensure the script doesn't look for `platform-xxx`
DEVICEREPO="http://github.com/volumio/platform-x86"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=no # Temporary until the repo is fixed

## Partition info
BOOT_START=1
BOOT_END=512
BOOT_TYPE=gpt        # msdos or gpt
INIT_TYPE="init.x86" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramfs
# Reveiw these for more mordern kernels?
MODULES=("overlay" "squashfs"
  # USB/FS modules
  "usbcore" "usb_common" "mmc_core" "mmc_block" "nvme_core" "nvme" "sdhci" "sdhci_pci" "sdhci_acpi"
  "ehci_pci" "ohci_pci" "uhci_hcd" "ehci_hcd" "xhci_hcd" "ohci_hcd" "usbhid" "hid_cherry" "hid_generic"
  "hid" "nls_cp437" "nls_utf8" "vfat"
  # Plymouth modules
  "intel_agp" "drm" "i915 modeset=1" "nouveau modeset=1" "radeon modeset=1"
  # Ata modules
  "acard-ahci" "ahci" "ata_generic" "ata_piix" "libahci" "libata"
  "pata_ali" "pata_amd" "pata_artop" "pata_atiixp" "pata_atp867x" "pata_cmd64x" "pata_cs5520" "pata_cs5530"
  "pata_cs5535" "pata_cs5536" "pata_efar" "pata_hpt366" "pata_hpt37x" "pata_isapnp" "pata_it8213"
  "pata_it821x" "pata_jmicron" "pata_legacy" "pata_marvell" "pata_mpiix" "pata_netcell" "pata_ninja32"
  "pata_ns87410" "pata_ns87415" "pata_oldpiix" "pata_opti" "pata_pcmcia" "pata_pdc2027x"
  "pata_pdc202xx_old" "pata_piccolo" "pata_rdc" "pata_rz1000" "pata_sc1200" "pata_sch" "pata_serverworks"
  "pata_sil680" "pata_sis" "pata_triflex" "pata_via" "pdc_adma" "sata_mv" "sata_nv" "sata_promise"
  "sata_qstor" "sata_sil24" "sata_sil" "sata_sis" "sata_svw" "sata_sx4" "ata_uli" "sata_via" "sata_vsc"
)
# Packages that will be installed
PACKAGES=(
  # Wireless firmware
  "firmware-b43-installer"
)

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"
  log "Copying kernel files"
  pkg_root="${PLTDIR}/packages-buster"
  cp "${pkg_root}"/linux-image-*.deb "${ROOTFSMNT}"
  log "Copying the latest firmware into /lib/firmware"
  tar xfJ "${pkg_root}"/linux-firmware-buster.tar.xz -C "${ROOTFSMNT}"

  log "Copying firmware additions"
  tar xf "${pkg_root}"/firmware-brcm-sdio-nvram/broadcom-nvram.tar.xz -C "${ROOTFSMNT}"
  cp "${pkg_root}"/firmware-cfg80211/* "${ROOTFSMNT}"/lib/firmware

  log "Copying Alsa Use Case Manager files"
  cp -R "${pkg_root}"/UCM/* "${ROOTFSMNT}"/usr/share/alsa/ucm/

  #TODO: not checked with other Intel SST bytrt/cht audio boards yet, needs more input
  #      to bew added to the snd_hda_audio tweaks (see below)
  mkdir -p "${ROOTFSMNT}"/usr/local/bin/
  cp "${pkg_root}"/bytcr-init/bytcr-init.sh "${ROOTFSMNT}"/usr/local/bin/
  chmod +x "${ROOTFSMNT}"/usr/local/bin/bytcr-init.sh

  log "Adding hda sound tweaks..."
  cp volumio/bin/volumio_hda_intel_tweak.sh "${ROOTFSMNT}"/usr/local/bin/volumio_hda_intel_tweak.sh
  chmod +x "${ROOTFSMNT}"/usr/local/bin/volumio_hda_intel_tweak.sh

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  log "Copying the Syslinux boot sector"
  dd conv=notrunc bs=440 count=1 if="${ROOTFSMNT}"/usr/lib/syslinux/mbr/gptmbr.bin of="${LOOP_DEV}"

  log "Creating efi folders"
  mkdir -p "${ROOTFSMNT}"/boot/efi
  mkdir -p "${ROOTFSMNT}"/boot/efi/EFI/debian
  mkdir -p "${ROOTFSMNT}"/boot/efi/BOOT/
  log "Copying bootloaders and grub configuration template"
  cp -R "${pkg_root}"/efi/* "${ROOTFSMNT}"/boot/efi
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  log "Running device_image_tweaks" "ext"

  log "Add script to set sane defaults for baytrail/cherrytrail soundcards"
  #TODO: add this to the Intel HD Audio tweak script see below
  cat <<-EOF >"${ROOTFSMNT}/etc/rc.local"
	#!/bin/sh -e
  /usr/local/bin/bytcr-init.sh
  /usr/local/bin/volumio_hda_intel_tweak.sh
  exut 0
	EOF

  log "Blacklisting PC speaker"
  cat <<-EOF >>"${ROOTFSMNT}/etc/modprobe.d/blacklist.conf"
	blacklist snd_pcsp
	blacklist pcspkr
	EOF
}

# Will be run in chroot (before other things)
device_chroot_tweaks() {
#log "Running device_image_tweaks" "ext"
  :
}

# Will be run in chroot - Pre initramfs
# TODO Try and streamline this!
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Installing the kernel"
  # Exact kernel version not known
  # Not brilliant, but safe enough as x86image.sh only copied one image
  ls /
  dpkg -i linux-image-*_i386.deb

  log "Getting the current kernel filename and version"
  KRNL=$(ls -l /boot | grep vmlinuz | awk '{print $9}')
  KVER=$(echo $KRNL | awk -F '-' '{print $2}')

  log "Finished Kernel installation" "okay" "${KRNL}"

  log "Preparing BIOS" "info"

  log "Installing Syslinux Legacy BIOS"
  syslinux -v
  syslinux "${BOOT_PART-?BOOT_PART is not known}"

  log "Preparing boot configurations" "info"

  log "Creating run-time template for syslinux config"
  log "Writing cmdline.txt file"

  KERNEL_LOGLEVEL="loglevel=0" # Default to KERN_EMERG
  DISABLE_PN="net.ifnames=0"   # For legacy ifnames in buster

  # Build up the base parameters
  kernel_params=(
    # Bios stuff
    "biosdevname=0"
    # Boot screen stuff
    "splash" "plymouth.ignore-serial-consoles"
    # Output console device and options.
    "quiet" "console=serial0,115200" "kgdboc=serial0,115200" "console=tty1"
    # Boot params
    "imgpart=UUID=%%IMGPART%%" "bootpart=UUID=%%BOOTPART%%" "datapart=UUID=%%DATAPART%%"
    # Image params
    "imgfile=/volumio_current.sqsh"
    # Disable linux logo during boot
    "logo.nologo"
    # Disable cursor
    "vt.global_cursor_default=0"
  )

  if [[ $DEBUG_IMAGE == yes ]]; then
    log "Creaing debug image" "wrn"
    KERNEL_LOGLEVEL="loglevel=8" # KERN_DEBUG
  fi
  kernel_params+=("${DISABLE_PN}")
  kernel_params+=("${KERNEL_LOGLEVEL}")

  log "Setting ${#kernel_params[@]} Kernel params:" "" "${kernel_params[*]}"

  # Create a template for init to use later in `update_config_UUIDs`
  cat <<-EOF >/boot/syslinux.tmpl
	DEFAULT volumio
	LABEL volumio
	SAY Legacy Boot Volumio Audiophile Music Player (default)
	LINUX ${KRNL}
	APPEND ${kernel_params[@]}
	INITRD volumio.initrd
	EOF

  log "Creating syslinux.cfg from template"
  cp /boot/syslinux.tmpl /boot/syslinux.cfg
  sed -i "s/%%IMGPART%%/${UUID_IMG}/g" /boot/syslinux.cfg
  sed -i "s/%%BOOTPART%%/${UUID_BOOT}/g" /boot/syslinux.cfg
  sed -i "s/%%DATAPART%%/${UUID_DATA}/g" /boot/syslinux.cfg

  log "Setting up Grub configuration" "info"
  log "Editing the Grub UEFI config template"
  log "Using current grub.cfg as run-time template for kernel updates"
  cp /boot/efi/BOOT/grub.cfg /boot/efi/BOOT/grub.tmpl

  log "Inserting root and boot partition UUIDs (building the boot cmdline used in initramfs)"
  # Opting for finding partitions by-UUID
  sed -i "s/%%IMGPART%%/${UUID_IMG}/g" /boot/efi/BOOT/grub.cfg
  sed -i "s/%%BOOTPART%%/${UUID_BOOT}/g" /boot/efi/BOOT/grub.cfg
  sed -i "s/%%DATAPART%%/${UUID_DATA}/g" /boot/efi/BOOT/grub.cfg
  sed -i "s/%%KVER%%/${KVER}/g" boot/efi/BOOT/grub.cfg
  sed -i "s/splash quiet loglevel=0/loglevel=8/g" /boot/efi/BOOT/grub.cfg

  log "Finished setting up boot config" "okay"

  log "Copying fstab as a template to be used in initrd"
  cp /etc/fstab /etc/fstab.tmpl

  log "Editing fstab to use UUID=<uuid of boot partition>"
  sed -i "s/%%BOOTPART%%/UUID=${UUID_BOOT}/g" /etc/fstab

  log "Setting plymouth theme to volumio"
  plymouth-set-default-theme volumio

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  log "No need to keep the original initrd"
  DELFILE=$(ls -l /boot | grep initrd.img | awk '{print $9}')
  rm "/boot/${DELFILE}"
  log "No need for the system map either"
  DELFILE=$(ls -l /boot | grep System.map | awk '{print $9}')
  log "Found ${DELFILE}, deleting"
  rm "/boot/${DELFILE}"
}
