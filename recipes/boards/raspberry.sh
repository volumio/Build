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
DEVICEBASE="raspberry"

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
	"bluez" "bluez-firmware" "pi-bluetooth"
	# Foundation stuff
	"raspberrypi-sys-mods"
	# GPIO stuff
	"wiringpi"
	# Boot splash
	"plymouth" "plymouth-themes"
	# Wireless firmware
	"firmware-atheros" "firmware-ralink" "firmware-realtek" "firmware-brcm80211"
	"libsox-dev"
)

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
	:
}

write_device_bootloader() {
	#TODO: Look into moving bootloader stuff here
	:
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
	log "Custom dtoverlay pre and post" "ext"
	# mkdir -p "${ROOTFSMNT}/opt/vc/bin/"
	# cp -rp "${SRC}"/volumio/opt/vc/bin/* "${ROOTFSMNT}/opt/vc/bin/"
	log "Copying shairport-sync service for arm"
	if [ -f "${SRC}/volumio/lib/systemd/system/shairport-sync.service" ]; then
		cp -rp "${SRC}/volumio/lib/systemd/system/shairport-sync.service" "${ROOTFSMNT}/lib/systemd/system"
	fi
	log "Fixing hostapd.conf"
	cat <<-EOF >"${ROOTFSMNT}/etc/hostapd/hostapd.conf"
		interface=wlan0
		driver=nl80211
		channel=4
		hw_mode=g
		wmm_enabled=0
		macaddr_acl=0
		ignore_broadcast_ssid=0
		# Auth
		auth_algs=1
		wpa=2
		wpa_key_mgmt=WPA-PSK
		rsn_pairwise=CCMP
		# Volumio specific
		ssid=Volumio
		wpa_passphrase=volumio2
	EOF

	#   log "Fixing vcgencmd and tvservice for Kodi"
	#   cat <<-EOF > ${ROOFTFSMNT}/etc/profile.d/vc-fix.sh
	# # Add aliases for vcgencmd and tvservice with proper paths
	# [ -f /opt/vc/bin/vcgencmd ] && alias vcgencmd="LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/vc/lib /opt/vc/bin/vcgencmd"
	# [ -f /opt/vc/bin/tvservice ] && alias tvservice="LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/vc/lib /opt/vc/bin/tvservice"
	# EOF
	# log "Symlinking vc bins"
	# # https://github.com/RPi-Distro/firmware/blob/debian/debian/libraspberrypi-bin.links
	# VC_BINS=("edidparser" "raspistill" "raspivid" "raspividyuv" "raspiyuv" \
	#          "tvservice" "vcdbg" "vcgencmd" "vchiq_test" \
	#           "dtoverlay" "dtoverlay" "dtoverlay-pre" "dtoverlay-post" "dtmerge")
	# for bin in "${VC_BINS[@]}"; do
	#     ln -s /opt/vc/bin/${bin} /usr/bin/${bin}
	# done

	cat <<-EOF >"${ROOTFSMNT}/etc/apt/sources.list.d/raspi.list"
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
	cat <<-EOF >"${ROOTFSMNT}/etc/apt/preferences.d/raspberrypi-kernel"
		Package: raspberrypi-bootloader
		Pin: release *
		Pin-Priority: -1

		Package: raspberrypi-kernel
		Pin: release *
		Pin-Priority: -1
	EOF

	log "Fetching rpi-update" "info"
	curl -L --output "${ROOTFSMNT}/usr/bin/rpi-update" https://raw.githubusercontent.com/volumio/rpi-update/master/rpi-update &&
		chmod +x "${ROOTFSMNT}/usr/bin/rpi-update"
	#TODO: Look into moving kernel stuff outside chroot using ROOT/BOOT_PATH to speed things up
	# ROOT_PATH=${ROOTFSMNT}
	# BOOT_PATH=${ROOT_PATH}/boot
}

# Will be run in chroot (before other things)
device_chroot_tweaks() {
	log "Running device_image_tweaks" "ext"
	# rpi-update needs binutils
	log "Installing binutils for rpi-update"
	apt-get update -qq && apt-get -yy install binutils
}

# Will be run in chroot - Pre initramfs
# TODO Try and streamline this!
device_chroot_tweaks_pre() {
	## Define parameters
	declare -A PI_KERNELS=(
		[4.19.86]="b9ecbe8d0e3177afed08c54fc938938100a0b73f"
		[4.19.97]="993f47507f287f5da56495f718c2d0cd05ccbc19"
		[4.19.118]="e1050e94821a70b2e4c72b318d6c6c968552e9a2"
		[5.4.51]="8382ece2b30be0beb87cac7f3b36824f194d01e9"
		[5.4.59]="caf7070cd6cece7e810e6f2661fc65899c58e297"
	)
	# Version we want
	KERNEL_VERSION="4.19.118"
	KERNEL_VERSION="5.4.59"
	IFS=\. read -ra KERNEL_SEMVER <<<"$KERNEL_VERSION"
	# List of custom firmware -
	# github archives that can be extracted directly
	declare -A CustomFirmware=(
		[AlloPiano]="https://github.com/allocom/piano-firmware/archive/master.tar.gz"
		# [TauDAC]="https://github.com/taudac/modules/archive/rpi-volumio-${KERNEL_VERSION}-taudac-modules.tar.gz" \
		[Bassowl]="https://raw.githubusercontent.com/Darmur/bassowl-hat/master/driver/archives/modules-rpi-${KERNEL_VERSION}-bassowl.tar.gz"
	)

	### Kernel installation
	KERNEL_COMMIT=${PI_KERNELS[$KERNEL_VERSION]}
	FIRMWARE_COMMIT=$KERNEL_COMMIT
	# using rpi-update relevant to defined kernel version
	log "Adding kernel ${KERNEL_VERSION} using rpi-update" "info"

	echo y | SKIP_BACKUP=1 WANT_PI4=1 SKIP_CHECK_PARTITION=1 UPDATE_SELF=0 /usr/bin/rpi-update "$KERNEL_COMMIT"
	log "Getting actual kernel revision with firmware revision backup"
	cp /boot/.firmware_revision /boot/.firmware_revision_kernel
	log "Updating bootloader files *.elf *.dat *.bin" "info"
	echo y | SKIP_KERNEL=1 WANT_PI4=1 SKIP_CHECK_PARTITION=1 UPDATE_SELF=0 /usr/bin/rpi-update "$FIRMWARE_COMMIT"

	if [ -d /lib/modules/$KERNEL_VERSION-v8+ ]; then
		log "Removing v8+ (pi4) Kernels" "info"
		rm /boot/kernel8.img
		rm -rf /lib/modules/$KERNEL_VERSION-v8+
	fi

	log "Finished Kernel installation" "okay"

	### Other Rpi specific stuff
	## Lets update some packages from raspbian repos now
	apt-get update && apt-get -y upgrade

	NODE_VERSION=$(node --version)
	log "Node version installed:" "dbg" "${NODE_VERSION}"
	# drop the leading v
	NODE_VERSION=${NODE_VERSION:1}
	if [[ ${NODE_VERSION%%.*} -ge 8 ]]; then
		log "Using a compatible nodejs version for all pi images" "info"
		# Get rid of armv7 nodejs and pick up the armv6l version
		if dpkg -s nodejs &>/dev/null; then
			log "Removing previous nodejs installation from $(command -v node)"
			log "Removing Node $(node --version) arm_version: $(node <<<'console.log(process.config.variables.arm_version)')" "info"
			apt-get -y purge nodejs
		fi
		arch=armv6l
		log "Installing Node for ${arch}"
		dpkg -i /volumio/customNode/nodejs_*-1unofficial_${arch}.deb
		log "Installed Node $(node --version) arm_version: $(node <<<'console.log(process.config.variables.arm_version)')" "info"

		# Block upgrade of nodejs from raspi repos
		log "Blocking nodejs updgrades for ${NODE_VERSION}"
		cat <<-EOF >"${ROOTFSMNT}/etc/apt/preferences.d/nodejs"
			Package: nodejs
			Pin: release *
			Pin-Priority: -1
		EOF
	fi
	log "Adding Shairport-Sync User"

	getent group shairport-sync &>/dev/null || groupadd -r shairport-sync >/dev/null
	getent passwd shairport-sync &>/dev/null || useradd -r -M -g shairport-sync -s /usr/bin/nologin -G audio shairport-sync >/dev/null

	log "Adding /opt/vc/lib to LD_LIBRARY_PATH"
	export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/vc/lib/

	log "Adding Custom DAC firmware from github" "info"
	for key in "${!CustomFirmware[@]}"; do
		wget -nv "${CustomFirmware[$key]}" -O "$key.tar.gz"
		tar --strip-components 1 --exclude "*.hash" --exclude "*.md" -xf "$key.tar.gz"
		rm "$key.tar.gz"
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
	echo "i2c-dev" >>/etc/modules

	log "Writing config.txt file"
	cat <<-EOF >>/boot/config.txt
		initramfs volumio.initrd
		gpu_mem=32
		max_usb_current=1
		dtparam=audio=on
		audio_pwm_mode=2
		dtparam=i2c_arm=on
		disable_splash=1
		hdmi_force_hotplug=1
		enable_uart=1

		include userconfig.txt
	EOF

	log "Writing cmdline.txt file"
	KERNEL_LOGLEVEL="loglevel=0" # Default to KERN_EMERG
	DISABLE_PN="net.ifnames=0"
	# Build up the base parameters
	kernel_params=(
		# Boot screen stuff
		"splash" "plymouth.ignore-serial-consoles"
		# Raspi USB controller params
		# TODO: Check if still required!
		"dwc_otg.fiq_enable=1" "dwc_otg.fiq_fsm_enable=1"
		"dwc_otg.fiq_fsm_mask=0xF" "dwc_otg.nak_holdoff=1"
		# Output console device and options.
		"quiet" "console=serial0,115200" "kgdboc=serial0,115200" "console=tty1"
		# Image params
		"imgpart=/dev/mmcblk0p2" "imgfile=/volumio_current.sqsh"
		# Wait for root device
		"rootwait" "bootdelay=5"
		# I/O scheduler
		"elevator=noop"
		# Disable linux logo during boot
		"logo.nologo"
		# Disable cursor
		"vt.global_cursor_default=0"
	)

	# Buster tweaks
	kernel_params+=("${DISABLE_PN}")
	# ALSA tweaks
	# ALSA compatibility needs to be set depending on kernel version, so use hacky semver check here
	[[ ${KERNEL_SEMVER[0]} == 5 ]] && compat_alsa=0 || compat_alsa=1
	kernel_params+=("snd-bcm2835.enable_compat_alsa=${compat_alsa}" "snd_bcm2835.enable_headphones=1")
	if [[ $DEBUG_IMAGE == yes ]]; then
		log "Adding Serial Debug parameters"
		echo "dtoverlay=pi3-miniuart-bt" >/boot/userconfig.txt
		KERNEL_LOGLEVEL="loglevel=8" # KERN_DEBUG
	fi

	kernel_params+=("${KERNEL_LOGLEVEL}")
	# shellcheck disable=SC2116
	log "Setting ${#kernel_params[@]} Kernel params:" "" "$(echo "${kernel_params[@]}")"
	cat <<-EOF >/boot/cmdline.txt
		${kernel_params[@]}
	EOF

	if [[ $DEBUG_IMAGE == yes ]] && [[ -f /boot/bootcode.bin ]]; then
		log "Enable serial boot debug"
		sed -i -e "s/BOOT_UART=0/BOOT_UART=1/" /boot/bootcode.bin
	fi

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

	# Rerun depmod for new drivers
	log "Finalising drivers installation with depmod on $KERNEL_VERSION+,-v7+ and -v7l+"
	depmod $KERNEL_VERSION+     # Pi 1, Zero, Compute Module
	depmod $KERNEL_VERSION-v7+  # Pi 2,3 CM3
	depmod $KERNEL_VERSION-v7l+ # Pi4

	log "Raspi Kernel and Modules installed" "okay"

	log "linking libsox for Spop"
	ln -s /usr/lib/arm-linux-gnueabihf/libsox.so /usr/local/lib/libsox.so.2
	log "linking libvchiq_arm and libvcos for mpd"
	ln -s /opt/vc/lib/libvchiq_arm.so /usr/lib/arm-linux-gnueabihf/
	ln -s /opt/vc/lib/libvcos.so /usr/lib/arm-linux-gnueabihf/
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
	:
}
