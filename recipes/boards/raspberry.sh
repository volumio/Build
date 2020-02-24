#!/usr/bin/env bash
# shellcheck disable=SC2034
## Setup for Raspberry Pi

## WIP: this should be refactored out to a higher level
# Aka base config for arm,armv7,armv8 and x86
# Base system
BASE="Raspbian"
ARCH="armhf"
BUILD="arm"

DEBUG_BUILD=no
### Device information
DEVICENAME="Raspberry Pi"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEBASE="pi"

# Disable to ensure the script doesn't look for `platform-xxx`
#DEVICEREPO=""

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes

## Partition info
BOOT_START=0
BOOT_END=96
BOOT_TYPE=msdos  # msdos or gpt
INIT_TYPE="init" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramfs
MODULES=("overlay" "squashfs")
# Packages that will be installed
PACKAGES=(# Bluetooth packages
  "bluez" "bluez-firmware" "pi-bluetooth"\
    # Foundation stuff
  "raspberrypi-sys-mods"\
    # GPIO stuff
  "wiringpi"\
    # Boot splash
  "plymouth" "plymouth-themes"\
    # Wireless firmware
  "firmware-atheros" "firmware-ralink" "firmware-realtek" "firmware-brcm80211" \
  )

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  :
}

write_device_bootloader(){
  #TODO: Look into moving bootloader stuff here
  :
}

# Will be called by the image builder for any customisation
device_image_tweaks(){
  log "Custom dtoverlay pre and post" "ext"
  mkdir -p ${ROOTFSMNT}/opt/vc/bin/
  cp -rp ${SRC}/volumio/opt/vc/bin/* ${ROOTFSMNT}/opt/vc/bin/

  cat <<-EOF > ${ROOTFSMNT}/etc/apt/sources.list.d/raspi.list
deb http://archive.raspberrypi.org/debian/ buster main ui
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
#deb-src http://archive.raspberrypi.org/debian/ buster main ui
EOF

  # raspberrypi-{kernel,bootloader} packages update kernel & firmware files
  # and break Volumio. Installation may be triggered by manual or
  # plugin installs explicitly or through dependencies like
  # chromium, sense-hat, picamera,...
  # Using Pin-Priority < 0 prevents installation
  log "Blocking raspberrypi-bootloader and raspberrypi-kernel"
  cat <<-EOF > ${ROOTFSMNT}/etc/apt/preferences.d/raspberrypi-kernel
Package: raspberrypi-bootloader
Pin: release *
Pin-Priority: -1

Package: raspberrypi-kernel
Pin: release *
Pin-Priority: -1
EOF

  log "Fetching rpi-update" "info"
  curl -L --output ${ROOTFSMNT}/usr/bin/rpi-update https://raw.githubusercontent.com/volumio/rpi-update/master/rpi-update && \
    chmod +x ${ROOTFSMNT}/usr/bin/rpi-update
  #TODO: Look into moving kernel stuff outside chroot using ROOT/BOOT_PATH
  # ROOT_PATH=${ROOTFSMNT}
  # BOOT_PATH=${ROOT_PATH}/boot
}

# Will be run in chroot (before other things)
device_chroot_tweaks(){
  log "Running device_image_tweaks" "ext"
  # rpi-update needs binutils
  log "Installing binutils for rpi-update"
  apt-get update -qq && apt-get -yy install binutils
}

# Will be run in chroot - Pre initramfs
# TODO Try and streamline this!
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"
  ## Define parameters
  declare -A PI_KERNELS=(\
      [4.19.86]="b9ecbe8d0e3177afed08c54fc938938100a0b73f"\
      [4.19.97]="dc4ba5be1babd3b3ec905751a30df89a5899a7a9"\
    )
  # Version we want
  KERNEL_VERSION="4.19.86"

  # List of custom firmware -
  # github archives that can be extracted directly
  declare -A CustomFirmware=(
    [AlloPiano]="https://github.com/allocom/piano-firmware/archive/master.tar.gz" \
      [TauDAC]="https://github.com/taudac/modules/archive/rpi-volumio-${KERNEL_VERSION}-taudac-modules.tar.gz" \
    )

  ### Kernel installation
  KERNEL_COMMIT=${PI_KERNELS[$KERNEL_VERSION]}
  FIRMWARE_COMMIT=$KERNEL_COMMIT
  # using rpi-update relevant to defined kernel version
  log "Adding kernel ${KERNEL_VERSION} using rpi-update" "info"

  echo y | SKIP_BACKUP=1 WANT_PI4=1 SKIP_CHECK_PARTITION=1 UPDATE_SELF=0 /usr/bin/rpi-update $KERNEL_COMMIT
  log "Getting actual kernel revision with firmware revision backup"
  cp /boot/.firmware_revision /boot/.firmware_revision_kernel
  log "Updating bootloader files *.elf *.dat *.bin" "info"
  echo y | SKIP_KERNEL=1 WANT_PI4=1 SKIP_CHECK_PARTITION=1 UPDATE_SELF=0 /usr/bin/rpi-update $FIRMWARE_COMMIT

  if [ -d /lib/modules/$KERNEL_VERSION-v8+ ]; then
    log "Removing v8+ (pi4) Kernels" "info"
    rm /boot/kernel8.img
    rm -rf /lib/modules/$KERNEL_VERSION-v8+
  fi

  log "Finished Kernel installation" "okay"

  ### Other Rpi specific stuff
  log "Adding Custom DAC firmware from github" "info"
  for key in "${!CustomFirmware[@]}"
  do
    wget -nv ${CustomFirmware[$key]} -O $key.tar.gz
    tar --strip-components 1 --exclude *.hash --exclude *.md -xf $key.tar.gz
    rm $key.tar.gz
  done

  log "Starting Raspi platform tweaks" "info"
  plymouth-set-default-theme volumio

  log "Adding gpio & spi group and permissions"
  groupadd -f --system gpio
  groupadd -f --system spi

  log "Disabling sshswitch"
  rm /etc/sudoers.d/010_pi-nopasswd
  unlink /etc/systemd/system/multi-user.target.wants/sshswitch.service
  rm /lib/systemd/system/sshswitch.service

  log "Changing external ethX priority"
  # As built-in eth _is_ on USB (smsc95xx or lan78xx drivers)
  sed -i 's/KERNEL==\"eth/DRIVERS!=\"smsc95xx\", DRIVERS!=\"lan78xx\", &/' /etc/udev/rules.d/99-Volumio-net.rules

  log "Adding volumio to gpio,i2c,spi group"
  usermod -a -G gpio,i2c,spi,input volumio

  log "Enabling i2c-dev module"
  echo "i2c-dev" >> /etc/modules

  log "Writing config.txt file"
  cat <<-EOF >> /boot/config.txt
initramfs volumio.initrd
gpu_mem=32
max_usb_current=1
dtparam=audio=on
audio_pwm_mode=2
dtparam=i2c_arm=on
disable_splash=1
hdmi_force_hotplug=1
enable_uart=1
dtoverlay=pi3-miniuart-bt

include userconfig.txt
EOF

  log "Writing cmdline.txt file"
  # DISABLE_PN=""
  DISABLE_PN="net.ifnames=0"
  echo "earlycon=serial0,115200 dwc_otg.fiq_enable=1 dwc_otg.fiq_fsm_enable=1 dwc_otg.fiq_fsm_mask=0xF dwc_otg.nak_holdoff=1 console=serial0,115200 kgdboc=serial0,115200 console=tty1 imgpart=/dev/mmcblk0p2 imgfile=/volumio_current.sqsh elevator=noop rootwait bootdelay=5 logo.nologo vt.global_cursor_default=0 loglevel=8 ${DISABLE_PN}" >> /boot/cmdline.txt

  # TODO is this still needed?
  # log "Linking DTOverlay utility"
  # ln -s /opt/vc/lib/libdtovl.so /usr/lib/libdtovl.so
  # ln -s /opt/vc/bin/dtoverlay /usr/bin/dtoverlay
  # ln -s /opt/vc/bin/dtoverlay-pre /usr/bin/dtoverlay-pre
  # ln -s /opt/vc/bin/dtoverlay-post /usr/bin/dtoverlay-post
  # log "Linking Vcgencmd"
  # ln -s /opt/vc/lib/libvchiq_arm.so /usr/lib/libvchiq_arm.so
  # ln -s /opt/vc/bin/vcgencmd /usr/bin/vcgencmd
  # ln -s /opt/vc/lib/libvcos.so /usr/lib/libvcos.so
  # log "Exporting /opt/vc/bin variable"
  # export LD_LIBRARY_PATH=/opt/vc/lib/:LD_LIBRARY_PATH

  log "Enable serial boot debug"
  if [[ $DEBUG_BUILD == yes ]] && [[ -f /boot/bootcode.bin ]]; then
    sed -i -e "s/BOOT_UART=0/BOOT_UART=1/" /boot/bootcode.bin
  fi

  # Rerun depmod for new drivers
  log "Finalising drivers installation with depmod on $KERNEL_VERSION+,-v7+ and -v7l+"
  depmod $KERNEL_VERSION+     # Pi 1, Zero, Compute Module
  depmod $KERNEL_VERSION-v7+  # Pi 2,3 CM3
  depmod $KERNEL_VERSION-v7l+ # Pi4

  log "Raspi Kernel and Modules installed" "okay"
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post(){
  :
}
