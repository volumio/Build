#!/usr/bin/env bash
# shellcheck disable=SC2034
## Setup for Raspberry Pi
DEVICE_SUPPORT_TYPE="S" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Raspbian"
ARCH="armhf"
BUILD="arm"

### Device information
# Used to identify devices (VOLUMIO_HARDWARE) and keep backward compatibility
#VOL_DEVICE_ID="pi"
DEVICENAME="Raspberry Pi"
# This is useful for multiple devices sharing the same/similar kernel
#DEVICEFAMILY="raspberry"

# Disable to ensure the script doesn't look for `platform-xxx`
#DEVICEREPO=""

### What features do we want to target
# TODO: Not fully implemented
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
	# "rpi-eeprom"\ Needs raspberrypi-bootloader that we hold back
	# GPIO stuff
	"wiringpi"
	# Boot splash
	"plymouth" "plymouth-themes"
	# Wireless firmware
	"firmware-atheros" "firmware-ralink" "firmware-realtek" "firmware-brcm80211"
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
	# log "Custom dtoverlay pre and post" "ext"
	# mkdir -p "${ROOTFSMNT}/opt/vc/bin/"
	# cp -rp "${SRC}"/volumio/opt/vc/bin/* "${ROOTFSMNT}/opt/vc/bin/"

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

	log "Adding archive.raspberrypi debian repo"
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
		#[KVER]="SHA|Branch"
		[4.19.86]="b9ecbe8d0e3177afed08c54fc938938100a0b73f|master"
		[4.19.97]="993f47507f287f5da56495f718c2d0cd05ccbc19|master"
		[4.19.118]="e1050e94821a70b2e4c72b318d6c6c968552e9a2|master"
		[5.4.51]="8382ece2b30be0beb87cac7f3b36824f194d01e9|master"
		[5.4.59]="caf7070cd6cece7e810e6f2661fc65899c58e297|master"
		[5.4.79]="0642816ed05d31fb37fc8fbbba9e1774b475113f|master"
		[5.4.81]="453e49bdd87325369b462b40e809d5f3187df21d|master"
		[5.4.83]="b7c8ef64ea24435519f05c38a2238658908c038e|stable"
		[5.10.3]="da59cb1161dc7c75727ec5c7636f632c52170961|master"
	)
	# Version we want
	KERNEL_VERSION="5.4.83"

	# For bleeding edge, check what is the latest on offer
	# Things *might* break, so you are warned!
	if [[ ${RPI_USE_LATEST_KERNEL:-no} == yes ]]; then
		branch=master
		log "Using bleeding edge Rpi kernel" "info" "$branch"
		RpiRepo="https://github.com/Hexxeh/rpi-firmware"
		RpiRepoApi=${RpiRepo/github.com/api.github.com\/repos}
		RpiRepoRaw=${RpiRepo/github.com/raw.githubusercontent.com}
		log "Fetching latest kernel details from ${RpiRepo}"
		RpiGitSHA=$(curl --silent "${RpiRepoApi}/branches/${branch}")
		readarray -t RpiCommitDetails <<<"$(jq -r '.commit.sha, .commit.commit.message' <<<"${RpiGitSHA}")"
		log "Rpi latest kernel -- ${RpiCommitDetails[*]}"
		KVER=$(curl --silent "${RpiRepoRaw}/${RpiCommitDetails[0]}/uname_string" | awk '{print $3}')
		KERNEL_VERSION=${KVER/+/}
		log "Using rpi-update SHA ${RpiCommitDetails[0]}" "${KERNEL_VERSION}"
		PI_KERNELS[${KERNEL_VERSION}]+="${RpiCommitDetails[0]}|${branch}"
	fi

	IFS=\. read -ra KERNEL_SEMVER <<<"${KERNEL_VERSION}"
	# List of custom firmware -
	# github archives that can be extracted directly
	declare -A CustomFirmware=(
		[AlloPiano]="https://github.com/allocom/piano-firmware/archive/master.tar.gz"
		[TauDAC]="https://github.com/taudac/modules/archive/rpi-volumio-${KERNEL_VERSION}-taudac-modules.tar.gz"
		[Bassowl]="https://raw.githubusercontent.com/Darmur/bassowl-hat/master/driver/archives/modules-rpi-${KERNEL_VERSION}-bassowl.tar.gz"
		[wm8960]="https://raw.githubusercontent.com/hftsai256/wm8960-rpi-modules/main/wm8960-modules-rpi-${KERNEL_VERSION}.tar.gz"
	)

	### Kernel installation
	KERNEL_COMMIT=${PI_KERNELS[$KERNEL_VERSION]%%|*}
	BRANCH=${PI_KERNELS[$KERNEL_VERSION]##*|}
	# using rpi-update to fetch and install kernel and firmware
	log "Adding kernel ${KERNEL_VERSION} using rpi-update" "info"
	log "Fetching SHA: ${KERNEL_COMMIT} from branch: ${BRANCH}"
	echo y | SKIP_BACKUP=1 WANT_PI4=1 SKIP_CHECK_PARTITION=1 UPDATE_SELF=0 BRANCH=$BRANCH /usr/bin/rpi-update "$KERNEL_COMMIT"

	if [ -d "/lib/modules/${KERNEL_VERSION}-v8+" ]; then
		log "Removing v8+ (pi4) Kernels" "info"
		rm /boot/kernel8.img
		rm -rf "/lib/modules/${KERNEL_VERSION}-v8+"
	fi

	log "Finished Kernel installation" "okay"

	### Other Rpi specific stuff
	## Lets update some packages from raspbian repos now
	apt-get update && apt-get -y upgrade

	NODE_VERSION=$(node --version)
	log "Node version installed:" "dbg" "${NODE_VERSION}"
	# drop the leading v
	NODE_VERSION=${NODE_VERSION:1}
	if [[ ${USE_NODE_ARMV6:-yes} == yes && ${NODE_VERSION%%.*} -ge 8 ]]; then
		log "Using a compatible nodejs version for all pi images" "info"
		# We don't know in advance what version is in the repo, so we have to hard code it.
		# This is temporary fix - make this smarter!
		declare -A NodeVersion=(
			[14]="https://repo.volumio.org/Volumio2/nodejs_14.15.4-1unofficial_armv6l.deb"
			[8]="https://repo.volumio.org/Volumio2/nodejs_8.17.0-1unofficial_armv6l.deb"
		)
		# TODO: Warn and proceed or exit the build?
		local arch=armv6l
		wget -nv "${NodeVersion[${NODE_VERSION%%.*}]}" -P /volumio/customNode || log "Failed fetching Nodejs for armv6!!" "wrn"
		# Proceed only if there is a deb to install
		if compgen -G "/volumio/customNode/nodejs_*-1unofficial_${arch}.deb" >/dev/null; then
			# Get rid of armv7 nodejs and pick up the armv6l version
			if dpkg -s nodejs &>/dev/null; then
				log "Removing previous nodejs installation from $(command -v node)"
				log "Removing Node $(node --version) arm_version: $(node <<<'console.log(process.config.variables.arm_version)')" "info"
				apt-get -y purge nodejs
			fi
			log "Installing Node for ${arch}"
			dpkg -i /volumio/customNode/nodejs_*-1unofficial_${arch}.deb
			log "Installed Node $(node --version) arm_version: $(node <<<'console.log(process.config.variables.arm_version)')" "info"
			rm -rf /volumio/customNode
		fi
		# Block upgrade of nodejs from raspi repos
		log "Blocking nodejs updgrades for ${NODE_VERSION}"
		cat <<-EOF >"${ROOTFSMNT}/etc/apt/preferences.d/nodejs"
			Package: nodejs
			Pin: release *
			Pin-Priority: -1
		EOF
	fi

	log "Adding Custom DAC firmware from github" "info"
	for key in "${!CustomFirmware[@]}"; do
		wget -nv "${CustomFirmware[$key]}" -O "$key.tar.gz" || {
			log "Failed to get firmware:" "err" "${key}"
			rm "$key.tar.gz"
			continue
		}
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

	log "Handling Video Core quirks" "info"

	log "Adding /opt/vc/lib to linker"
	cat <<-EOF >/etc/ld.so.conf.d/00-vmcs.conf
		/opt/vc/lib
	EOF
	log "Updating LD_LIBRARY_PATH"
	ldconfig

	log "Symlinking vc bins"
	# https://github.com/RPi-Distro/firmware/blob/debian/debian/libraspberrypi-bin.links
	VC_BINS=("edidparser" "raspistill" "raspivid" "raspividyuv" "raspiyuv"
		"tvservice" "vcdbg" "vcgencmd" "vchiq_test"
		"dtoverlay" "dtoverlay-pre" "dtoverlay-post" "dtmerge")
	for bin in "${VC_BINS[@]}"; do
		ln -s "/opt/vc/bin/${bin}" "/usr/bin/${bin}"
	done

	log "Fixing vcgencmd permissions"
	cat <<-EOF >/etc/udev/rules.d/10-vchiq.rules
		SUBSYSTEM=="vchiq",GROUP="video",MODE="0660"
	EOF

	log "Setting bootparms and modules" "info"
	log "Enabling i2c-dev module"
	echo "i2c-dev" >>/etc/modules

	log "Writing config.txt file"
	cat <<-EOF >/boot/config.txt
		initramfs volumio.initrd
		gpu_mem=32
		max_usb_current=1
		dtparam=audio=on
		audio_pwm_mode=2
		dtparam=i2c_arm=on
		disable_splash=1
		hdmi_force_hotplug=1

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
		"quiet" "console=serial0,115200" "console=tty1"
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
	# ALSA compatibility needs to be set depending on kernel version,
	# so use hacky semver check here in the odd case we want to go back to a lower kernel
	[[ ${KERNEL_SEMVER[0]} == 5 ]] && compat_alsa=0 || compat_alsa=1
	# https://github.com/raspberrypi/linux/commit/88debfb15b3ac9059b72dc1ebc5b82f3394cac87
	if [[ ${KERNEL_SEMVER[0]} == 5 ]] && [[ ${KERNEL_SEMVER[2]} -le 4 ]] && [[ ${KERNEL_SEMVER[2]} -le 79 ]]; then
		kernel_params+=("snd_bcm2835.enable_headphones=1")
	fi
	kernel_params+=("snd-bcm2835.enable_compat_alsa=${compat_alsa}" "snd_bcm2835.enable_hdmi=1")

	if [[ $DEBUG_IMAGE == yes ]]; then
		log "Creating debug image" "wrn"
		log "Adding Serial Debug parameters"
		echo "include debug.txt" >>/boot/config.txt
		cat <<-EOF >/boot/debug.txt
			# Enable serial console for boot debugging
			enable_uart=1
			dtoverlay=pi3-miniuart-bt
		EOF
		KERNEL_LOGLEVEL="loglevel=8" # KERN_DEBUG
		log "Enabling SSH"
		touch /boot/ssh
		if [[ -f /boot/bootcode.bin ]]; then
			log "Enable serial boot debug"
			sed -i -e "s/BOOT_UART=0/BOOT_UART=1/" /boot/bootcode.bin
		fi
	fi

	kernel_params+=("${KERNEL_LOGLEVEL}")
	log "Setting ${#kernel_params[@]} Kernel params:" "${kernel_params[*]}"
	cat <<-EOF >/boot/cmdline.txt
		${kernel_params[@]}
	EOF

	# Rerun depmod for new drivers
	log "Finalising drivers installation with depmod on ${KERNEL_VERSION}+,-v7+ and -v7l+"
	depmod "${KERNEL_VERSION}+"     # Pi 1, Zero, Compute Module
	depmod "${KERNEL_VERSION}-v7+"  # Pi 2,3 CM3
	depmod "${KERNEL_VERSION}-v7l+" # Pi4

	log "Raspi Kernel and Modules installed" "okay"

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
	# log "Running device_chroot_tweaks_post" "ext"
	:
}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
	# log "Running device_image_tweaks_post" "ext"
	:
}
