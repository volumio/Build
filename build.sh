#!/bin/bash
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

log "Running Volumio Image Builder -" "info"

ARCH=""
SUITE="buster"
#Help function
function HELP() {
  echo "

Help documentation for Volumio Image Builder

Basic usage: ./build.sh -b arm -d pi -v 2.0

Switches:
  -b <arch> Build a full system image with Multistrap.
            Options for the target architecture are 'arm' (Raspbian), 'armv7' (Debian arm64), 'armv8' (Debian arm64) or 'x86' (Debian i386).
  -d        Create Image for Specific Devices. Supported device names:
              pi, udooneo, udooqdl, cuboxi, cubietruck, compulab,
              odroidc1, odroidc2, odroidxu4, sparky, bbb, pine64,
              bpim2u, bpipro, tinkerboard, sopine64, rock64, voltastream0, nanopi64,
              nanopineo2, nanopineo, nanopineo
  -v <vers> Version must be a dot separated number. Example 1.102 .

  -l <repo> Create docker layer. Give a Docker Repository name as the argument.
  -p <dir>  Optionally patch the builder. <dir> should contain a tree of
            files you want to replace within the build tree. Experts only.

Example: Build a Raspberry PI image from scratch, version 2.0 :
         ./build.sh -b arm -d pi -v 2.0 -l reponame
  "
  exit 1
}

mount_chroot() {
  local base=$1
  local
  log "Mounting temp devices for chroot at ${base}" "info"
  if [[ ${BUILD} == x86 ]]; then
    log "Mounting /dev for x86 chroot" "dbg"
    # x86's grub-mkconfig (well grub-probe) needs /dev mounted
    mount --bind /proc "${base}/proc"
    mount --bind /sys "${base}/sys"
    mount --bind /dev "${base}/dev"
    mount --bind /dev/pts "${base}/dev/pts"
    mount --bind /run "${base}/run"
  else
    mount /sys "${base}/sys" -t sysfs
    mount /proc "${base}/proc" -t proc
    mount chdev "${base}/dev" -t devtmpfs || mount --bind /dev "${base}/dev"
    mount chpts "${base}/dev/pts" -t devpts
  fi

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
  umount -l "${base}/run" || log "umount run failed" "wrn"

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
  log "Adding ${VERSION} and ${DEVICE} to os-release" "info"
  cat <<-EOF >>"${os_release}"
	VOLUMIO_VERSION="${VERSION}"
	VOLUMIO_HARDWARE="${DEVICE}"
	EOF
}

## Fetch the NodeJS BE and FE
function fetch_volumio_from_repo() {
  log 'Cloning Volumio Node Backend'
  [[ -d "${ROOTFS}/volumio" ]] && rm -r "${ROOTFS}/volumio"

  mkdir "${ROOTFS}/volumio"

  if [ -n "$PATCH" ]; then
    log "Cloning Volumio with all its history"
    git clone https://github.com/volumio/Volumio2.git "${ROOTFS}/volumio"
  else
    log "Cloning Volumio from ${VOL_BE_REPO} - ${VOL_BE_REPO_BRANCH}"
    git clone --depth 1 -b "${VOL_BE_REPO_BRANCH}" --single-branch "${VOL_BE_REPO}" "${ROOTFS}/volumio"
  fi

  log 'Cloning Volumio UI'
  git clone --depth 1 -b dist --single-branch https://github.com/volumio/Volumio2-UI.git "${ROOTFS}/volumio/http/www"
  git clone --depth 1 -b dist3 --single-branch https://github.com/volumio/Volumio2-UI.git "${ROOTFS}/volumio/http/www3"
  log "Adding Volumio revision information to os-release"
  cat <<-EOF >>"${ROOTFS}/etc/os-release"
	VOLUMIO_BUILD_VERSION="$(git rev-parse HEAD)"
	VOLUMIO_FE_VERSION="$(git --git-dir "${ROOTFS}/volumio/http/www/.git" rev-parse HEAD)"
	VOLUMIO_FE3_VERSION="$(git --git-dir "${ROOTFS}/volumio/http/www3/.git" rev-parse HEAD)"
	VOLUMIO_BE_VERSION="$(git --git-dir "${ROOTFS}/volumio/.git" rev-parse HEAD)"
	VOLUMIO_ARCH="${BUILD}"
	EOF

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

  log "Adding SecureApt keys to rootfs"
  for key in "${!SecureApt[@]}"; do
    apt-key --keyring "${DirEtctrustedparts}/${key}" \
      adv --fetch-keys "${SecureApt[$key]}"
  done
}

function patch_multistrap_conf_raspbian() {
  log "Patching multistrap config to point to Raspbian sources" "info"
  BASECONF=recipes/base/VolumioBase.conf
  export RASPBIANCONF=recipes/base/arm-raspbian.conf
  debian_source=https://deb.debian.org/debian
  rapsbian_source=https://archive.raspbian.org/raspbian
  upmpdcli_source=http://www.lesbonscomptes.com/upmpdcli/downloads

  cat <<-EOF >"${SRC}/${RASPBIANCONF}"
	# Auto generated multistrap configuration for Raspberry Pi
	# Please do not edit this file, add extra Raspberry Pi specific packages to <arm.conf> which build upon this base
	# Using pi's debian source containing packages built for armhf with ARMv6 ISA (VFP2) instead of Debian's ARMv7 ISA(VFP3) 
	EOF

  sed "s|^source=${debian_source}|source=${rapsbian_source}|g; s|^source=${upmpdcli_source}/debian/|source=${upmpdcli_source}/raspbian|g" "${SRC}/${BASECONF}" >>"${SRC}/${RASPBIANCONF}"

  log "Raspbian multistrap config created at ${RASPBIANCONF##*/}"
}

#Check the number of arguments. If none are passed, print help and exit.
NUMARGS=$#
if [ "$NUMARGS" -eq 0 ]; then
  HELP
fi

while getopts b:v:d:p:t:e:h: FLAG; do
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
    # l)
    #   #Create docker layer
    #   CREATE_DOCKER_LAYER=1
    #   DOCKER_REPOSITORY_NAME=$OPTARG
    # ;;
  p)
    PATCH=$OPTARG
    ;;
  h) #show help
    HELP
    ;;
  t)
    VARIANT=$OPTARG
    ;;
  /?) #unrecognized option - show help
    echo -e \\n"Option -${bold}$OPTARG${normal} not allowed."
    HELP
    ;;
  esac
done

shift $((OPTIND - 1))

log "Checking whether we are running as root"
if [ "$(id -u)" -ne 0 ]; then
  log "Please run the build script as root" "err"
  exit 1
fi

start=$(date +%s)

## Setup logging
#TODO make this smarter.
log "Creating log directory"
LOG_DIR=${SRC}/logging/build_"$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$LOG_DIR"
# But it's annoying if root needs to delete it, soo
chmod 777 "$LOG_DIR"/

if [ -z "${VARIANT}" ]; then
  log "Setting default Volumio variant"
  VARIANT="volumio"
fi

if [ -n "${BUILD}" ]; then
  log "Creating ${BUILD} rootfs" "info"
  #TODO Check naming conventions!
  BASE="Debian"
  if [[ ! -f "$SUITE" ]]; then
    log "Defaulting to release" "" "Buster"
    SUITE="buster"
  fi

  MULTSTRAPCONF=${BUILD}
  if [ "${BUILD}" = arm ] || [ "${BUILD}" = arm-dev ]; then
    ARCH="armhf"
    BUILD="arm"
    patch_multistrap_conf_raspbian
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
    ARCH="amd64"
    BUILD="x64"
  fi

  # For easier debugging we add config flag
  if [[ ${USE_MULTISTRAP_CASCADE:-yes} == yes ]]; then
    CONF="${SRC}/recipes/base/${MULTSTRAPCONF}.conf"
  else
    CONF="${SRC}/recipes/base/${MULTSTRAPCONF}-$SUITE.conf"
  fi

  if [[ ! -f $CONF ]]; then
    log "No base system configuration file found" "wrn" "$(basename "$CONF")"
    exit 1
  fi

  # Setup output directory

  if [ -d "${SRC}/build/${BUILD}" ]; then
    log "${BUILD} rootfs exists, cleaning it"
    rm -rf "${SRC}/build/${BUILD}"
  fi
  ROOTFS="${SRC}/build/${BUILD}/root"
  mkdir -p "${ROOTFS}"

  setup_multistrap

  log "Building ${BASE} System for ${BUILD} ($ARCH)" "info"
  log "Creating rootfs in <./build/${BUILD}/root>"

  #### Build stage 0 - Multistrap
  log "Running multistrap for ${BUILD} (${ARCH})" "" "${CONF##*/}"

  # shellcheck disable=SC2069
  if ! multistrap -a "$ARCH" -d "${ROOTFS}" -f "$CONF" 2>&1 >"${LOG_DIR}/multistrap.log"; then # if ! { multistrap -a "$ARCH" -f "$CONF" > /dev/null; } 2>&1
    log "Multistrap failed. Exiting" "err"
    exit 1
  else
    end_multistrap=$(date +%s)
    time_it "$end_multistrap" "$start"
    # Incase multistrap's list are left over
    if compgen -G "${ROOTFS}/etc/apt/sources.list.d/multistrap-*.list" >/dev/null; then
      log "Removing multistrap-*.list" "wrn"
      rm "${ROOTFS}"/etc/apt/sources.list.d/multistrap-*.list
    fi
    [[ -n ${RASPBIANCONF} ]] && [[ -e "${SRC}/${RASPBIANCONF}" ]] && rm "${SRC}/${RASPBIANCONF}"
    log "Finished setting up Multistrap rootfs" "okay" "$TIME_STR"
  fi

  log "Preparing for Volumio chroot configuration" "info"
  start_chroot=$(date +%s)

  cp scripts/volumio/volumioconfig.sh "${ROOTFS}"
  cp scripts/helpers.sh "${ROOTFS}"

  mount_chroot "${ROOTFS}"

  fetch_volumio_from_repo
  #TODO: We set a lot of things here that are then copied in later,
  # restructure this!
  log "Configuring Volumio" "info"
  chroot "${ROOTFS}" /volumioconfig.sh

  # Copy the dpkg log
  mv "${ROOTFS}/dpkg.log" "${LOG_DIR}/dpkg.log"
  ###Dirty fix for mpd.conf TODO use volumio repo
  cp "${SRC}/volumio/etc/mpd.conf" "${ROOTFS}/etc/mpd.conf"

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
  # shellcheck source=./scripts/volumio/configure.sh
  source "${SRC}/scripts/volumio/configure.sh"

  log "Volumio rootfs created" "okay"
  # Bundle up the base rootfs
  log "Creating base system rootfs tarball"
  # https://superuser.com/questions/168749/is-there-a-way-to-see-any-tar-progress-per-file/665181#665181
  rootfs_tarball="${SRC}/build/${BUILD}"_rootfs
  tar cp --xattrs --directory=build/${BUILD}/root/ \
    --exclude='./dev/*' --exclude='./proc/*' \
    --exclude='./run/*' --exclude='./tmp/*' \
    --exclude='./sys/*' . |
    pv -p -b -r -s "$(du -sb build/${BUILD}/ | cut -f1)" -N "$rootfs_tarball" | lz4 -c >"${rootfs_tarball}.lz4"
  log "Created ${BUILD}_rootfs.lz4" "okay"
else
  use_rootfs_tarball=yes
fi

#### Build stage 1 - Device specific image creation

#TODO: Streamline this for multiple devices that are siblings
if [[ -n "$DEVICE" ]]; then
  DEV_CONFIG="${SRC}/recipes/devices/${DEVICE}.sh"
  if [[ -f $DEV_CONFIG ]]; then
    # shellcheck source=/dev/null
    source "$DEV_CONFIG"
    log "Preparing an image for ${DEVICE} using $BASE - ${BUILD}"
    if [[ $use_rootfs_tarball == yes ]]; then
      log "Trying to use prior base system" "info"
      if [[ -d ${SRC}/build/${BUILD} ]]; then
        log "Prior ${BUILD} rootfs dir found!" "dbg" "$(date -r "${SRC}/build/${BUILD}" "+%m-%d-%Y %H:%M:%S")"
        [[ ${CLEAN_ROOTFS:-yes} == yes ]] &&
          log "Cleaning prior rootfs directory" "wrn" && rm -rf "${SRC}/build/${BUILD}"
      fi
      rootfs_tarball="${SRC}/build/${BUILD}"_rootfs
      [[ ! -f ${rootfs_tarball}.lz4 ]] && log "Couldn't find prior base system!" "err" && exit 1
      log "Using prior Base tarball"
      mkdir -p ./build/${BUILD}/root
      pv -p -b -r -c -N "[ .... ] $rootfs_tarball" "${rootfs_tarball}.lz4" |
        lz4 -dc |
        tar xp --xattrs -C ./build/${BUILD}/root
    fi
    ROOTFS="${SRC}/build/${BUILD}/root"
  else
    log "No configuration found for <${DEVICE}>" "err"
    exit 1
  fi

  ## Add in our version details
  check_os_release

  ## How do we work with this -
  #TODO
  if [ -n "$PATCH" ]; then
    log "Copying Patch ${PATCH} to Rootfs"
    cp -rp "$PATCH" "${ROOTFS}/"
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
  if [[ ${UPDATE_VOLUMIO:-no} == yes ]]; then
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
    tar xf "${SRC}"/modules/node_modules_${BUILD}_v${NODE_VERSION%%.*}.*.tar.xz -C "${ROOTFS}/volumio"
    ls "${ROOTFS}/volumio/node_modules"
  else
    # Current Volumio repo knows only {arm|x86} which is conveniently the same length
    # TODO: Consolidate the naming scheme for node modules - %{BUILD}-v${NODE_VERSION}.tar.xz
    log "Attempting to fetch node_modules for ${NODE_VERSION} -- ${NODE_SEMVER[*]}"
    modules_url="${NODE_MODULES_REPO}/node_modules_${BUILD:0:3}-${NODE_VERSION}.tar.gz"
    log "Fetching node_modules from ${modules_url}"
    curl -L "${modules_url}" | tar xz -C "${ROOTFS}/volumio"
  fi

  ## Copy custom packages for Volumio
  if [[ ${USE_LOCAL_PACKAGES:-no} == yes ]]; then
    mkdir -p "${ROOTFS}"/volumio/customPkgs
    log "Adding packages from local ${SRC}/customPkgs/"
    cp "${SRC}"/customPkgs/*"${BUILD}".deb "${ROOTFS}"/volumio/customPkgs/
    # Pi's need an armvl6 build of nodejs (for Node > v8)
    if [[ ${DEVICE} == raspberry && ${USE_NODE_ARMV6:-yes} == yes && ${NODE_SEMVER[0]} -ge 8 ]]; then
      mkdir -p "${ROOTFS}"/volumio/customNode/ && cp "${SRC}"/customPkgs/nodejs_${NODE_VERSION%%.*}*-1unofficial_armv6l.deb "$_"
      log "Added custom Node binary:" "" "$(ls "${ROOTFS}"/volumio/customNode)"
    fi
  elif [[ ${CUSTOM_PKGS[*]} ]]; then
    log "Adding customPkgs from external repo" "info"
    for key in "${!CUSTOM_PKGS[@]}"; do
      log "Fetching ${key} from ${CUSTOM_PKGS[$key]}"
      wget -nv "${CUSTOM_PKGS[$key]}" -P "${ROOTFS}"/volumio/customPkgs/
    done
  else
    log "No customPkgs added!" "wrn"
  fi
  # shellcheck disable=SC2012
  [[ -d "${ROOTFS}"/volumio/customPkgs ]] && log "Added custom packages:" "" "$(ls -b "${ROOTFS}"/volumio/customPkgs | tr '\n' ' ')"
  # Prepare Images
  start_img=$(date +%s)
  BUILDDATE=$(date -I)
  IMG_FILE="Volumio-${VERSION}-${BUILDDATE}-${DEVICE}.img"

  if [[ ${OLD_X86BUILD:no} == yes ]] && [[ ${BUILD} == x86 ]]; then
    log "Using old x86 image script to build image"
    # shellcheck source=scripts/x86image.sh
    source "${SRC}/scripts/x86image.sh"
  else
    # shellcheck source=scripts/makeimage.sh
    source "${SRC}/scripts/makeimage.sh"
  fi
  end_img=$(date +%s)
  time_it "$end_img" "$start_img"
  log "Image ${IMG_FILE} Created" "okay" "$TIME_STR"
  log "Compressing image"
  start_zip=$(date +%s)
  ZIP_FILE=${IMG_FILE%.*}.zip
  zip "${ZIP_FILE}" "${IMG_FILE}"*
  end_zip=$(date +%s)
  time_it "$end_zip" "$start_zip"
  log "Image ${ZIP_FILE} Created [ ${yellow}${standout}$(du -h "${ZIP_FILE}" | cut -f1)${normal} ]" "okay" "$TIME_STR"
  [[ ${CLEAN_IMAGE_FILE:-no} == yes ]] && rm "${IMG_FILE}"*
else
  log "No device specified, only base rootfs created!" "wrn"
fi

end_build=$(date +%s)
time_it "$end_build" "$start"

log "Cleaning up rootfs.." "info" "build/${BUILD}/"
rm -r build/${BUILD:?}/ || log "Couldn't clean rootfs" "wrn"

log "Volumio Builder finished: \
$([[ -n ${BUILD} ]] && echo "${yellow}BUILD=${standout}${BUILD}${normal} ")\
$([[ -n $DEVICE ]] && echo "${yellow}DEVICE=${standout}${DEVICE}${normal}  ")\
$([[ -n $VERSION ]] && echo "${yellow}VERSION=${standout}${VERSION}${normal} ")\
${normal}" "okay" "$TIME_STR"
