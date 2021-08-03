#!/usr/bin/env bash
# Volumio Image Builder
# Copyright Michelangelo Guarise - Volumio.org
#
# TODO: Add gé credits
#
# Dependencies:
# parted squashfs-tools dosfstools multistrap qemu binfmt-support qemu-user-static kpartx

set -eo pipefail

SRC="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

# Load helpers
# shellcheck source=./scripts/helpers.sh
source "${SRC}/scripts/helpers.sh"
export -f log
export -f time_it
export -f isMounted

# Load config
# shellcheck source=./scripts/config.sh
source "${SRC}/scripts/config.sh"
mapfile -t DEVICE_LIST < <(basename -s .sh "${SRC}"/recipes/devices/*.sh | sort)

log "Running Volumio Image Builder -" "info"

#Help function
function HELP() {
  cat <<-EOF
Help documentation for Volumio Image Builder
Basic usage: ./build.sh -b arm -d pi -v 2.0
Switches:
  -b <arch>     Build a base rootfs with Multistrap.
                Options for the target architecture are 
  'arm' (Raspbian armhf 32bit), 'armv7' (Debian armhf 32bit), 'armv8' (Debian arm64 64bit) 
  'x86' (Debian i386 64bit) or 'x64' (Debian amd64 64bit).
  -d <device>   Create Image for Specific Devices. Supported device names
$(printf "\t\t%s\n" "${DEVICE_LIST[@]}")
  -v <version>  Version must be a dot separated number. Example <1.102>.
  -- Advanced features --
  -t <variant>  Volumio Variant type.
  -p <dir>      Optionally patch the builder. <dir> should contain a tree of
                files you want to replace within the build tree. Experts only.
Example: Build a Raspberry PI image from scratch, version 2.0 :
         ./build.sh -b arm -d pi -v 2.0
EOF
  exit 1
}

mount_chroot() {
  local base=$1
  log "Mounting temp devices for chroot at ${base}" "info"
  mount /sys "${base}/sys" -t sysfs
  mount /proc "${base}/proc" -t proc
  mount chdev "${base}/dev" -t devtmpfs || mount --bind /dev "${base}/dev"
  mount chpts "${base}/dev/pts" -t devpts
  # Lets record this, might come in handy.
  CHROOT=yes
  export CHROOT
}

unmount_chroot() {
  local base=$1
  log "Unmounting chroot temporary devices at ${base}"
  umount -l "${base}/dev" || log "umount dev failed" "wrn"
  umount -l "${base}/proc" || log "umount proc failed" "wrn"
  umount -l "${base}/sys" || log "umount sys failed" "wrn"

  # Setting up cgmanager under chroot/qemu leaves a mounted fs behind, clean it up
  if [[ -d "${base}/run/cgmanager/fs" ]]; then
    umount -l "${base}/run/cgmanager/fs" || log "unmount cgmanager failed" "wrn"
  fi
  CHROOT=no
}

exit_error() {
  log "Build script failed!!" "err"
  # Check if there are any mounts that need cleaning up
  # If dev is mounted, the rest should also be mounted (right?)
  if isMounted "${ROOTFS}/dev"; then
    unmount_chroot "${ROOTFS}"
  fi
}

trap exit_error INT ERR

function check_os_release() {
  os_release="${ROOTFS}/etc/os-release"
  # This shouldn't be required anymore - we pack the rootfs tarball at base level
  if grep "VOLUMIO_VERSION" "${os_release}"; then
    # os-release already has a VERSION number
    # remove prior version and hardware
    log "Removing previous VOLUMIO_VERSION and VOLUMIO_HARDWARE from os-release"
    sed -i '/^\(VOLUMIO_VERSION\|VOLUMIO_HARDWARE\)/d' "${os_release}"
  fi
  # We keep backward compatibly for some cases for devices with ambiguous names
  # mainly raspberry -> pi
  log "Adding ${VERSION} and ${VOL_DEVICE_ID:-${DEVICE}} to os-release" "info"
  cat <<-EOF >>"${os_release}"
	VOLUMIO_VERSION="${VERSION}"
	VOLUMIO_HARDWARE="${VOL_DEVICE_ID-${DEVICE}}"
	EOF
}

## Fetch the NodeJS BE and FE
function fetch_volumio_from_repo() {
  log 'Cloning Volumio Node Backend'
  [[ -d "${ROOTFS}/volumio" ]] && rm -r "${ROOTFS}/volumio"

  mkdir "${ROOTFS}/volumio"

  log "Cloning Volumio from ${VOL_BE_REPO} - ${VOL_BE_REPO_BRANCH}"
  git clone --depth 10 -b "${VOL_BE_REPO_BRANCH}" --single-branch "${VOL_BE_REPO}" "${ROOTFS}/volumio"
  if [[ -n ${VOL_BE_REPO_SHA} ]]; then
    log "Setting BE_REPO to commit" "${VOL_BE_REPO_SHA}"
    git -C "${ROOTFS}/volumio/" reset --hard "${VOL_BE_REPO_SHA}"
  fi
  log "Adding precommit hooks"
  cat <<-EOF >"${ROOTFS}/volumio/.git/hooks/pre-commit"
	#!/bin/bash
	# Pre-commit hook, uncomment when finished linting all codebase
	#npm run lint-staged
	EOF

  log "Adding wireless.js"
  cp "${SRC}/volumio/bin/wireless.js" "${ROOTFS}/volumio/app/plugins/system_controller/network/wireless.js"
  log 'Cloning Volumio UI'
  git clone --depth 1 -b dist --single-branch https://github.com/volumio/Volumio2-UI.git "${ROOTFS}/volumio/http/www"
  git clone --depth 1 -b dist3 --single-branch https://github.com/volumio/Volumio2-UI.git "${ROOTFS}/volumio/http/www3"

  log "Adding Volumio revision information to os-release"
  BUILD_VER=$(git rev-parse HEAD)
  FE_VER=$(git --git-dir "${ROOTFS}/volumio/http/www/.git" rev-parse HEAD)
  FE3_VER=$(git --git-dir "${ROOTFS}/volumio/http/www3/.git" rev-parse HEAD)
  BE_VER=$(git --git-dir "${ROOTFS}/volumio/.git" rev-parse HEAD)

  if grep -q VOLUMIO_FE_VERSION "${ROOTFS}"/etc/os-release; then
    log "Updating Volumio rev"
    sed -i -e "s|\(^VOLUMIO_BUILD_VERSION=\).*|\1\"${BUILD_VER}\"|" \
      -e "s|\(^VOLUMIO_FE_VERSION=\).*|\1\"${FE_VER}\"|" \
      -e "s|\(^VOLUMIO_FE3_VERSION=\).*|\1\"${FE3_VER}\"|" \
      -e "s|\(^VOLUMIO_BE_VERSION=\).*|\1\"${BE_VER}\"|" \
      "${ROOTFS}"/etc/os-release
  else
    log "Appending Volumio rev"
    cat <<-EOF >>"${ROOTFS}"/etc/os-release
		VOLUMIO_BUILD_VERSION="${BUILD_VER}"
		VOLUMIO_FE_VERSION="${FE_VER}"
		VOLUMIO_FE3_VERSION="${FE3_VER}"
		VOLUMIO_BE_VERSION="${BE_VER}"
		VOLUMIO_ARCH="${BUILD}"
		EOF
  fi
  cat "${ROOTFS}"/etc/os-release
  # Clean up git repo
  rm -rf "${ROOTFS}/volumio/http/www/.git"
  rm -rf "${ROOTFS}/volumio/http/www3/.git"

  log "Cloned Volumio BE" "okay" "$(git --git-dir "${ROOTFS}/volumio/.git" log --oneline -1)"

}

function setup_multistrap() {
  log "Setting up Multistrap environment" "info"
  log "Preparing rootfs apt-config"
  DirEtc="${ROOTFS}"/etc/apt
  DirEtcparts=${DirEtc}/apt.conf.d
  DirEtctrustedparts=${DirEtc}/trusted.gpg.d

  mkdir -p "${DirEtcparts}"
  mkdir -p "${DirEtctrustedparts}"
  echo -e 'Dpkg::Progress-Fancy "1";\nAPT::Color "1";' > \
    "${DirEtcparts}"/01progress

  if [[ -n "${APT_CACHE}" ]] && ! curl -sSf "${APT_CACHE}" >/dev/null; then
    cat <<-EOF >"${DirEtcparts}/02cache"
		Acquire::http { Proxy "${APT_CACHE}"; };
		EOF
  fi

  log "Adding SecureApt keys to rootfs"
  for key in "${!SecureApt[@]}"; do
    apt-key --keyring "${DirEtctrustedparts}/${key}" \
      adv --fetch-keys "${SecureApt[$key]}"
  done
  if [[ ${ARCH} == $(dpkg --print-architecture) ]]; then
    # Some packages need more help, give it to them
    log "Creating /dev/urandom for multistrap on native arch"
    mkdir "${ROOTFS}/dev/"
    mknod "${ROOTFS}/dev/urandom" c 1 9
    chmod 640 "${ROOTFS}/dev/urandom"
    chown 0:0 "${ROOTFS}/dev/urandom"
  fi
}

function patch_multistrap_conf() {
  local type="$1"
  case "$type" in
  raspbian)
    log "Patching multistrap config to point to Raspbian sources" "info"
    BASECONF=recipes/base/VolumioBase.conf
    export RASPBIANCONF=recipes/base/arm-raspbian.conf
    debian_source=http://deb.debian.org/debian
    rapsbian_source=http://archive.raspbian.org/raspbian

    cat <<-EOF >"${SRC}/${RASPBIANCONF}"
		# Auto generated multistrap configuration for Raspberry Pi
		# Please do not edit this file, add extra Raspberry Pi specific packages to <arm.conf> which build upon this base
		# Using pi's debian source containing packages built for armhf with ARMv6 ISA (VFP2) instead of Debian's ARMv7 ISA(VFP3)
		EOF
    sed "s|^source=${debian_source}|source=${rapsbian_source}|g; s|^source=${upmpdcli_source}/debian/|source=${upmpdcli_source}/raspbian|g" "${SRC}/${BASECONF}" >>"${SRC}/${RASPBIANCONF}"
    log "Raspbian multistrap config created at ${RASPBIANCONF##*/}"
    ;;
  x64)
    log "Patching x86 multistrap config for x86_amd64" "info"
    log "Nothing to do for now!"
    # This is just so we don't need to maintain a x64 multistrap recipe
    ;;
  *)
    log "Multistrap patch ${type} is unknown" "error"
    exit 1
    ;;
  esac
}

function check_supported_device() {

  if [[ -n "${DEVICE}" ]]; then # Device flag was provided
    DEV_CONFIG="${SRC}/recipes/devices/${DEVICE}.sh"
    if [[ ! -f "${DEV_CONFIG}" ]]; then
      log "No configuration found for <${DEVICE}>" "err"
      log "Build system currently supports ${#DEVICE_LIST[@]} devices:" "${DEVICE_LIST[*]}"
      exit 1
    fi
  elif [[ -n "${BUILD}" ]]; then # Build flag with no Device
    log "No device flag passed to builder, building only ${BASE}" "wrn"
  else
    log "No Base or Device flag found.." "wrn"
    HELP
  fi
}

#Check the number of arguments. If none are passed, print help and exit.
[[ "$#" -eq 0 ]] && HELP

while getopts b:v:d:p:t:h: FLAG; do
  case $FLAG in
  b)
    BUILD=$OPTARG
    ;;
  d)
    DEVICE=$OPTARG
    ;;
  v)
    VERSION=$OPTARG
    ;;
  p)
    PATCH=$OPTARG
    ;;
  h) #show help
    HELP
    ;;
  t)
    VARIANT=$OPTARG
    ;;
  \?) #unrecognized option - show help
    echo -e \\n"Option -${bold}$OPTARG${normal} not allowed."
    HELP
    ;;
  esac
done
# move past our parsed args
shift $((OPTIND - 1))

check_supported_device

log "Checking whether we are running as root"
if [ "$(id -u)" -ne 0 ]; then
  log "Please run the build script as root" "err"
  exit 1
fi

start=$(date +%s)

## Setup logging and dirs
#TODO make this smarter.
BUILD_OUTPUT_DIR=${BUILD_OUTPUT_DIR:-${SRC}/build}
OUTPUT_DIR=${OUTPUT_DIR:-.}
LOG_DIR="${OUTPUT_DIR}/debug_$(date +%Y-%m-%d_%H-%M-%S)"
LOCAL_PKG_DIR=${LOCAL_PKG_DIR:-customPkgs}
LOCAL_MODULES_DIR=${LOCAL_MODULES_DIR:-modules}

if [[ -z "$SUITE" ]]; then
  log "Defaulting to release" "" "Buster"
  SUITE="buster"
fi

if [[ -n ${BUILD} ]]; then
  log "Creating log directory"
  mkdir -p "$LOG_DIR"
  # But it's annoying if root needs to delete it, soo
  chmod -R 777 "$LOG_DIR"/
fi
if [ -z "${VARIANT}" ]; then
  log "Setting default Volumio variant"
  VARIANT="volumio"
fi

if [ -n "${BUILD}" ]; then
  log "Creating ${BUILD} rootfs" "info"
  #TODO Check naming conventions!
  BASE="Debian"

  MULTISTRAPCONF=${BUILD}
  if [ "${BUILD}" = arm ] || [ "${BUILD}" = arm-dev ]; then
    ARCH="armhf"
    BUILD="arm"
    patch_multistrap_conf "raspbian"
    BASE="Raspbian"
  elif [ "${BUILD}" = armv7 ] || [ "${BUILD}" = armv7-dev ]; then
    ARCH="armhf"
    BUILD="armv7"
  elif [ "${BUILD}" = armv8 ] || [ "${BUILD}" = armv8-dev ]; then
    ARCH="arm64"
    BUILD="armv8"
  elif [ "${BUILD}" = x86 ] || [ "${BUILD}" = x86-dev ]; then
    ARCH="i386"
    BUILD="x86"
  elif [ "${BUILD}" = x64 ] || [ "${BUILD}" = x64-dev ]; then
    patch_multistrap_conf "x64"
    MULTISTRAPCONF=x86
    ARCH="amd64"
    BUILD="x64"
  fi

  CONF="${SRC}/recipes/base/${MULTISTRAPCONF}.conf"

  if [[ ! -f $CONF ]]; then
    log "No base system configuration file found" "wrn" "$(basename "$CONF")"
    exit 1
  fi

  # Setup build directory
  BUILD_DIR=${BUILD_OUTPUT_DIR}/${SUITE}/${BUILD}
  rootfs_tarball=${BUILD_DIR}_rootfs

  if [[ -d "${BUILD_DIR}" ]]; then
    log "${BUILD} rootfs exists, cleaning it" "wrn" "${BUILD_DIR}"
    rm -rf "${BUILD_DIR}"
  fi
  ROOTFS="${BUILD_DIR}/root"
  mkdir -p "${ROOTFS}"

  setup_multistrap

  log "Building ${BASE} System for ${BUILD} ($ARCH)" "info"
  log "Creating rootfs in <${BUILD_DIR}>"

  #### Build stage 0 - Multistrap
  log "Running multistrap for ${BUILD} (${ARCH})" "" "${CONF##*/}"
  multistrap -a "$ARCH" -d "${ROOTFS}" -f "$CONF" --simulate >"${LOG_DIR}/multistrap_packages.log"
  # shellcheck disable=SC2069
  if ! multistrap -a "$ARCH" -d "${ROOTFS}" -f "$CONF" 2>&1 >"${LOG_DIR}/multistrap.log"; then # if ! { multistrap -a "$ARCH" -f "$CONF" > /dev/null; } 2>&1
    log "Multistrap failed. Exiting" "err"
    exit 1
  else
    end_multistrap=$(date +%s)
    time_it "$end_multistrap" "$start"
    # Clean up multistrap
    # Incase multistrap's list are left over
    if compgen -G "${ROOTFS}/etc/apt/sources.list.d/multistrap-*.list" >/dev/null; then
      log "Removing multistrap-*.list" "wrn"
      rm "${ROOTFS}"/etc/apt/sources.list.d/multistrap-*.list
    fi
    [[ -n ${RASPBIANCONF} ]] && [[ -e "${SRC}/${RASPBIANCONF}" ]] && rm "${SRC}/${RASPBIANCONF}"
    log "Finished setting up Multistrap rootfs" "okay" "$TIME_STR"
  fi

  log "Preparing rootfs before chroot" "info"
  # shellcheck source=./scripts/rootfs/prepare.sh
  source "${SRC}/scripts/rootfs/prepare.sh"

  log "Preparing for Volumio chroot configuration" "info"
  start_chroot=$(date +%s)

  cp scripts/helpers.sh "${ROOTFS}"
  cp scripts/rootfs/volumioconfig.sh "${ROOTFS}"

  mount_chroot "${ROOTFS}"

  fetch_volumio_from_repo
  #TODO: We set a lot of things here that are then copied in later,
  # restructure this!
  log "Configuring Volumio" "info"
  chroot "${ROOTFS}" /volumioconfig.sh

  # Copy the dpkg log
  mv "${ROOTFS}/dpkg.log" "${LOG_DIR}/dpkg.log"

  CUR_DATE=$(date)
  #Write some Version information
  log "Writing system information"
  cat <<-EOF >>"${ROOTFS}"/etc/os-release
	VOLUMIO_VARIANT="${VARIANT}"
	VOLUMIO_TEST="FALSE"
	VOLUMIO_BUILD_DATE="${CUR_DATE}"
	EOF

  unmount_chroot "${ROOTFS}"

  end_chroot=$(date +%s)
  time_it "$end_chroot" "$start_chroot"

  log "Base rootfs Installed" "okay" "$TIME_STR"
  rm -f "${ROOTFS}/volumioconfig.sh"

  log "Running Volumio configuration script on rootfs" "info"
  # shellcheck source=./scripts/rootfs/configure.sh
  source "${SRC}/scripts/rootfs/configure.sh"

  log "Volumio rootfs created" "okay"
  # Bundle up the base rootfs
  log "Creating base system rootfs tarball"
  # https://superuser.com/questions/168749/is-there-a-way-to-see-any-tar-progress-per-file/665181#665181
  tar cp --xattrs --directory="${ROOTFS}" \
    --exclude='./dev/*' --exclude='./proc/*' \
    --exclude='./run/*' --exclude='./tmp/*' \
    --exclude='./sys/*' . |
    pv -p -b -r -s "$(du -sb "${BUILD_DIR}" | cut -f1)" -N "$rootfs_tarball" | lz4 -c >"${rootfs_tarball}.lz4"
  log "Created ${BUILD}_rootfs.lz4" "okay"
else
  use_rootfs_tarball=yes
fi

#### Build stage 1 - Device specific image creation

if [[ -n "${DEVICE}" ]]; then
  # shellcheck source=/dev/null
  source "$DEV_CONFIG"
  log "Preparing an image for ${DEVICE} using $BASE - ${BUILD}"
  # Parse build directory
  BUILD_DIR=${BUILD_OUTPUT_DIR}/${SUITE}/${BUILD}
  rootfs_tarball=${BUILD_DIR}_rootfs
  if [[ $use_rootfs_tarball == yes ]]; then
    log "Trying to use prior base system" "info"
    if [[ -d ${BUILD_DIR} ]]; then
      log "Prior ${BUILD} rootfs dir found!" "dbg" "$(date -r "${BUILD_DIR}" "+%m-%d-%Y %H:%M:%S")"
      [[ ${CLEAN_ROOTFS:-yes} == yes ]] &&
        log "Cleaning prior rootfs directory" "wrn" && rm -rf "${BUILD_DIR}"
    fi
    [[ ! -f ${rootfs_tarball}.lz4 ]] && log "Couldn't find prior base system!" "err" && exit 1
    log "Using prior Base tarball" "$(date -r "${rootfs_tarball}.lz4" "+%m-%d-%Y %H:%M:%S")"
    mkdir -p "${BUILD_DIR}/root"
    pv -p -b -r -c -N "[ .... ] $rootfs_tarball" "${rootfs_tarball}.lz4" |
      lz4 -dc |
      tar xp --xattrs -C "${BUILD_DIR}/root"
  fi
  ROOTFS="${BUILD_DIR}/root"

  ## Add in our version details
  check_os_release

  ## How do we work with this -
  #TODO
  if [ -n "$PATCH" ]; then
    log "Copying Patch ${SDK_PATH-.}/${PATCH} to Rootfs"
    cp -rp "${SDK_PATH-.}/${PATCH}" "${ROOTFS}/"
  else
    log "No patches found, defaulting to Volumio rootfs"
    PATCH='volumio'
  fi

  ## Testing and debugging
  if [[ $USE_BUILD_TESTS == yes ]]; then
    log "Running Tests for ${BUILD}"
    if [[ -d "${SRC}/tests" ]]; then
      mkdir -p "${ROOTFS}/tests"
      for file in "${SRC}"/tests/*.sh; do
        cp "${file}" "${ROOTFS}"/tests/
      done
      mount_chroot "${ROOTFS}"
      for file in "${ROOTFS}"/tests/*.sh; do
        chroot "${ROOTFS}" /tests/"$(basename "$file")"
      done
      unmount_chroot "${ROOTFS}"
      log "Done, exiting"
      exit 0
    fi
  fi

  ## Update the FE/BE
  log "Checking upstream status of Volumio Node BE" "info"
  REPO_URL=${VOL_BE_REPO/github.com/api.github.com\/repos}
  REPO_URL="${REPO_URL%.*}/branches/${VOL_BE_REPO_BRANCH}"
  GIT_STATUS=$(curl --silent "${REPO_URL}")
  readarray -t COMMIT_DETAILS <<<"$(jq -r '.commit.sha, .commit.commit.message' <<<"${GIT_STATUS}")"
  log "Upstream Volumio BE details" "dbg" "${COMMIT_DETAILS[0]:0:8} ${COMMIT_DETAILS[1]}"
  [[ ! "$(git --git-dir "${ROOTFS}/volumio/.git" rev-parse HEAD)" == "${COMMIT_DETAILS[0]}" ]] && log "Rootfs git is not in sync with upstream repo!" "wrn"
  # Update only if we are using a prior rootfs -- if we just built one, it should already be up to spec
  if [[ ${use_rootfs_tarball} == yes ]] && [[ ${UPDATE_VOLUMIO:-yes} == yes ]]; then
    log "Updating Volumio Node BE/FE"
    fetch_volumio_from_repo
  else
    log "Using base tarball's Volumio Node BE/FE" "info" "$(git --git-dir "${ROOTFS}/volumio/.git" log --oneline -1)"
  fi

  ## Copy modules/packages
  # TODO: Streamline node versioning!
  # Major version modules tarballs should be sufficient.
  IFS=\. read -ra NODE_SEMVER <<<"$NODE_VERSION"
  log "Adding custom Packages and Modules" "info"
  if [[ ${USE_LOCAL_NODE_MODULES:-no} == yes ]]; then
    log "Extracting node_modules for Node v${NODE_VERSION}"
    tar xf "${LOCAL_MODULES_DIR}"/node_modules_${BUILD}_v${NODE_VERSION%%.*}.*.tar.xz -C "${ROOTFS}/volumio"
    ls "${ROOTFS}/volumio/node_modules"
  else
    # Current Volumio repo knows only {arm|x86} which is conveniently the same length
    # TODO: Consolidate the naming scheme for node modules - %{BUILD}-v${NODE_VERSION}.tar.xz
    log "Attempting to fetch node_modules for ${NODE_VERSION} -- ${NODE_SEMVER[*]}"
    # Workaround for x64 modules being built for a different version
    [[ ${BUILD} == x64 ]] && [[ ${NODE_SEMVER[0]} == 0 ]] && {
      log "Overiding NODE_VERSION from ${NODE_VERSION} to 8.17.0" "wrn"
      NODE_VERSION=8.17.0
    }
    modules_url="${NODE_MODULES_REPO}/node_modules_${BUILD:0:3}-${NODE_VERSION}.tar.gz"
    log "Fetching node_modules from ${modules_url}"
    curl -L "${modules_url}" | tar xz -C "${ROOTFS}/volumio" || log "Failed fetching node modules!!" "err"
  fi

  ## Copy custom packages for Volumio
  #TODO: Remove this once local debugging is done, and all debs are online somewhere
  # Default dir is ./customPkgs
  if [[ ${USE_LOCAL_PACKAGES:-no} == yes ]]; then
    mkdir -p "${ROOTFS}"/volumio/customPkgs
    log "Adding packages from dir ${LOCAL_PKG_DIR}"
    [[ -d "${LOCAL_PKG_DIR}"/ ]] && cp "${LOCAL_PKG_DIR}"/*"${BUILD}".deb "${ROOTFS}"/volumio/customPkgs/
    # Pi's need an armvl6 build of nodejs (for Node > v8)
    #if [[ ${DEVICE} == raspberry && ${USE_NODE_ARMV6:-yes} == yes && ${NODE_SEMVER[0]} -ge 8 ]]; then
    #  mkdir -p "${ROOTFS}"/volumio/customNode/ && cp "${LOCAL_PKG_DIR}"/nodejs_${NODE_VERSION%%.*}*-1unofficial_armv6l.deb "$_"
    #  log "Added custom Node binary:" "" "$(ls "${ROOTFS}"/volumio/customNode)"
    #fi
  elif [[ ${CUSTOM_PKGS[*]} ]]; then
    log "Adding customPkgs from external repo" "info"
    for key in "${!CUSTOM_PKGS[@]}"; do
      # TODO: Test if key is specific to BUILD or not!
      url=${CUSTOM_PKGS[$key]}
      [[ "$url" != *".deb"$ ]] && url="${url}_${BUILD}.deb"
      # log "Fetching ${key} from ${url}"
      wget -nv "${url}" -P "${ROOTFS}/volumio/customPkgs/" || log "${key} not found for ${BUILD}!" "err"
    done
  else
    log "No customPkgs added!" "wrn"
  fi
  # shellcheck disable=SC2012
  [[ -d "${ROOTFS}"/volumio/customPkgs ]] && log "Added custom packages:" "" "$(ls -b "${ROOTFS}"/volumio/customPkgs | tr '\n' ' ')"
  # Prepare Images
  start_img=$(date +%s)
  BUILDDATE=$(date -I)
  IMG_FILE="${VARIANT^}-${VERSION}-${BUILDDATE}-${DEVICE}.img"

  # shellcheck source=scripts/makeimage.sh
  source "${SRC}/scripts/makeimage.sh"
  end_img=$(date +%s)
  time_it "$end_img" "$start_img"
  log "Image ${IMG_FILE} Created" "okay" "$TIME_STR"
  log "Compressing image"
  start_zip=$(date +%s)
  ZIP_FILE="${OUTPUT_DIR}/$(basename -s .img "${IMG_FILE}").zip"
  zip -j "${ZIP_FILE}" "${IMG_FILE}"*
  end_zip=$(date +%s)
  time_it "$end_zip" "$start_zip"
  log "Image ${ZIP_FILE} Created [ ${yellow}${standout}$(du -h "${ZIP_FILE}" | cut -f1)${normal} ]" "okay" "$TIME_STR"
  [[ ${CLEAN_IMAGE_FILE:-yes} == yes ]] && rm "${IMG_FILE}"*
else
  log "No device specified, only base rootfs created!" "wrn"
fi

end_build=$(date +%s)
time_it "$end_build" "$start"

log "Cleaning up rootfs.." "info" "${BUILD_DIR}"
rm -r "${BUILD_DIR:?}" || log "Couldn't clean rootfs" "wrn"

log "Volumio Builder finished: \
$([[ -n ${BUILD} ]] && echo "${yellow}BUILD=${standout}${BUILD}${normal} ")\
$([[ -n $DEVICE ]] && echo "${yellow}DEVICE=${standout}${DEVICE}${normal}  ")\
$([[ -n $VERSION ]] && echo "${yellow}VERSION=${standout}${VERSION}${normal} ")\
${normal}" "okay" "$TIME_STR"
