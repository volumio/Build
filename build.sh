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
function HELP {
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
  log "Mounting temp devices for chroot at ${base}" "info"
  mount /proc "${base}/proc" -t proc
  mount /sys "${base}/sys" -t sysfs
  mount chdev "${base}/dev" -t devtmpfs || mount --bind /dev "${base}/dev"
  mount chpts "${base}/dev/pts" -t devpts

  # Lets record this, might come in handy.
  CHROOT=yes
  export CHROOT
}

unmount_chroot(){
  local base=$1
  log "Unmounting chroot temporary devices at ${base}"
  umount -l "${base}/dev"  || log "umount dev failed" "wrn"
  umount -l "${base}/proc" || log "umount proc failed" "wrn"
  umount -l "${base}/sys"  || log "umount sys failed" "wrn"

  # Setting up cgmanager under chroot/qemu leaves a mounted fs behind, clean it up
  if [[ -d "${base}/run/cgmanager/fs" ]]; then
    umount -l "${base}/run/cgmanager/fs" || log "unmount cgmanager failed" "wrn"
  fi
  CHROOT=no
}

exit_error () {
  log "Build script failed!!" "err"
  # Check if there are any mounts that need cleaning up
  # If dev is mounted, the rest should also be mounted (right?)
  if isMounted "${ROOTFS}/dev"; then
    unmount_chroot "${ROOTFS}"
  fi
}

trap exit_error INT ERR

#$1 = ${BUILD} $2 = ${VERSION} $3 = ${DEVICE}"
function check_os_release {
  ## This shouldn't be required anymore - we pack the rootfs tarball at base level
  # local build=$1
  # VERSION=$2
  # DEVICE=$3
  os_release="build/${BUILD}/root/etc/os-release"
  HAS_VERSION="grep -c VOLUMIO_VERSION $os_release"
  if $HAS_VERSION; then
    log "Removing previous VOLUMIO_VERSION"
    # os-release already has a VERSION number
    # remove prior version and hardware
    sed -i '/^\(VOLUMIO_VERSION\|VOLUMIO_HARDWARE\)/d' "$os_release"
  fi
  log "Adding ${VERSION} and ${DEVICE} to os-release" "info"
  echo "VOLUMIO_VERSION=\"${VERSION}\"" >> "$os_release"
  echo "VOLUMIO_HARDWARE=\"${DEVICE}\"" >> "$os_release"
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
    h)  #show help
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

shift $((OPTIND-1))

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
    log "Defaulting to Debian" "" "Buster"
    SUITE="buster"
  fi

  if [ "${BUILD}" = arm ] || [ "${BUILD}" = arm-dev ]; then
    ARCH="armhf"
    BUILD="arm"
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
  fi

  CONF="${SRC}/recipes/base/${BUILD}-$SUITE.conf"

  if [[ ! -f $CONF ]]; then
    log "No base system configuration file found" "wrn" "$(basename "$CONF")"
    exit 1
  fi

  log "Building ${BASE} System for ${BUILD} ($ARCH)" "info"

  # Setup output directory

  if [ -d "${SRC}/build/${BUILD}" ]; then
    log "${BUILD} rootfs exists, cleaning it"
    rm -rf "${SRC}/build/${BUILD}"
  fi
  ROOTFS="${SRC}/build/${BUILD}/root"
  mkdir -p "${ROOTFS}"

  log "Creating rootfs in <./build/${BUILD}/root>"

  #### Build stage 0 - Multistrap
  ### Multistrap
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
  for key in "${!SecureApt[@]}"
  do
    apt-key --keyring "${DirEtctrustedparts}/${key}" \
      adv --fetch-keys "${SecureApt[$key]}"
  done

  log "Running multistrap for ${BUILD} (${ARCH})"
  # shellcheck disable=SC2069
  if ! multistrap -a "$ARCH" -f "$CONF"  2>&1 > "${LOG_DIR}/multistrap.log"
  # if ! { multistrap -a "$ARCH" -f "$CONF" > /dev/null; } 2>&1
  then
    log "Multistrap failed. Exiting" "err"
    exit 1
  else
    end_multistrap=$(date +%s)
    time_it "$end_multistrap" "$start"
    log "Finished setting up Multistrap rootfs" "okay" "$TIME_STR"
  fi


  log "Preparing for Volumio chroot configuration" "info"
  start_chroot=$(date +%s)

  cp scripts/volumio/volumioconfig.sh "${ROOTFS}"
  cp scripts/helpers.sh "${ROOTFS}"

  mount_chroot "${ROOTFS}"

  log 'Cloning Volumio Node Backend'
  mkdir "${ROOTFS}/volumio"

  if [ -n "$PATCH" ]; then
    log "Cloning Volumio with all its history"
    git clone https://github.com/volumio/Volumio2.git "${ROOTFS}/volumio"
  else
    log "Cloning Volumio from ${VOL_BE_REPO} - ${VOL_BE_REPO_BRANCH}"
    git clone --depth 1 -b ${VOL_BE_REPO_BRANCH} --single-branch ${VOL_BE_REPO} "${ROOTFS}/volumio"
  fi

  log 'Cloning Volumio UI'
  git clone --depth 1 -b dist  --single-branch https://github.com/volumio/Volumio2-UI.git "${ROOTFS}/volumio/http/www"
  git clone --depth 1 -b dist3 --single-branch https://github.com/volumio/Volumio2-UI.git "${ROOTFS}/volumio/http/www3"
  log "Adding Volumio revision information to os-release"
  cat <<-EOF >> "${ROOTFS}/etc/os-release"
	VOLUMIO_BUILD_VERSION="$(git rev-parse HEAD)"
	VOLUMIO_FE_VERSION="$(git --git-dir "${ROOTFS}/volumio/http/www/.git" rev-parse HEAD)"
	VOLUMIO_FE3_VERSION="$(git --git-dir "${ROOTFS}/volumio/http/www3/.git" rev-parse HEAD)"
	VOLUMIO_BE_VERSION="$(git --git-dir "${ROOTFS}/volumio/.git" rev-parse HEAD)"
	VOLUMIO_ARCH="${BUILD}"
	EOF
  # Clean up git repo
  rm -rf "${ROOTFS}/volumio/http/www/.git"
  rm -rf "${ROOTFS}/volumio/http/www3/.git"

  log "Configuring Volumio" "info"
  chroot "${ROOTFS}" /volumioconfig.sh

  # Copy the dpkg log
  mv "${ROOTFS}/dpkg.log" "${LOG_DIR}/dpkg.log"
  ###Dirty fix for mpd.conf TODO use volumio repo
  cp "${SRC}/volumio/etc/mpd.conf" "${ROOTFS}/etc/mpd.conf"

  CUR_DATE=$(date)
  #Write some Version information
  log "Writing system information"
  cat <<-EOF >>  "build/${BUILD}/root/etc/os-release"
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
    --exclude='./sys/*' . \
    | pv -p -b -r -s "$(du -sb build/${BUILD}/ | cut -f1)" -N "$rootfs_tarball" | lz4 -c > "${rootfs_tarball}.lz4"
  log "Created ${BUILD}_rootfs.lz4" "okay"
else
  use_rootfs_tarball=yes
fi


#### Build stage 1 - Device specific image creation

#TODO: Streamline this for multiple devices that are siblings
if [[ -n "$DEVICE" ]]; then
  DEV_CONFIG="${SRC}/recipes/boards/${DEVICE}.sh"
  if [[ -f $DEV_CONFIG ]]; then
    # shellcheck source=/dev/null
    source "$DEV_CONFIG"
    log "Preparing an image for ${DEVICE} using $BASE - ${BUILD}"
    if [[ $use_rootfs_tarball == yes ]]; then
      log "Trying to use prior base system" "info"
      if [[ -d ${SRC}/build/${BUILD} ]]; then
        log "Using prior Base system"
      else
      rootfs_tarball="${SRC}/build/${BUILD}"_rootfs
      [[ ! -f ${rootfs_tarball}.lz4 ]] && log "Couldn't find prior base system!" "err" && exit 1
      log "Using prior Base tarball"
      mkdir -p ./build/${BUILD}/root
      pv -p -b -r -c -N "[ .... ] $rootfs_tarball" "${rootfs_tarball}.lz4" \
        | lz4 -dc \
        | tar xp --xattrs -C ./build/${BUILD}/root
      fi
      ROOTFS="${SRC}/build/${BUILD}/root"

    fi
  else
    log "No configuration found for $DEVICE" "err"
    exit 1
  fi

  ## Add in our version details
  check_os_release

  ## How do we work with this -
  #TODO
  if [ -n "$PATCH" ]; then
    log "Copying Patch ${PATCH} to Rootfs"
    cp -rp "$PATCH"  "${ROOTFS}/"
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
        cp "${file}"  "${ROOTFS}"/tests/
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

  ## Copy modules/packages
  # TODO: Streamline node versioning! 
  # Major version modules tarballs should be sufficient.
  IFS=\. read -ra NODE_SEMVER <<<"$NODE_VERSION"
  if [[ ${USE_LOCAL_NODE_MODULES:-no} == yes ]]; then
    log "Extracting node_modules for Node v${NODE_VERSION}"
    tar xf "${SRC}"/modules/node_modules_${BUILD}_v${NODE_VERSION%%.*}.*.tar.xz -C "${ROOTFS}/volumio"
    ls "${ROOTFS}/volumio/node_modules"
  else 
    # Current Volumio repo knows only {arm|x86} which is conviniently the same lenght
    # TODO: Consolidate the naming schme for node modules - %{BUILD}-v${NODE_VERSION}.tar.xz 
    log "Attempting to fetch node_modules for ${NODE_VERSION} -- ${NODE_SEMVER[*]}"
    modules_url="${NODE_MODULES_REPO}/node_modules_${BUILD:0:3}-${NODE_VERSION}.tar.gz"
    log "Fetching node_modules from ${modules_url}"
    curl -L "${modules_url}" | tar xz -C "${ROOTFS}/volumio"
  fi

  ## Copy custom packages for Volumio
  mkdir -p "${ROOTFS}"/volumio/customPkgs
  if [[ ${USE_LOCAL_PACKAGES:-no} == yes ]]; then
    log "Adding packages from local ${SRC}/customPkgs/"
    cp "${SRC}"/customPkgs/*"${BUILD}".deb  "${ROOTFS}"/volumio/customPkgs/
    # Pi's need an armvl6 build of nodejs (for Node > v8)
    [[ ${DEVICE} == raspberry && ${NODE_SEMVER[0]} -ge 8 ]] && mkdir -p "${ROOTFS}"/volumio/customNode/ && cp "${SRC}"/customPkgs/nodejs_${NODE_VERSION%%.*}*-1unofficial_armv6l.deb "$_"
    ls "${ROOTFS}"/volumio/customPkgs
  else 
    log "Adding customPkgs from external repo" "info"
    for key in "${!CUSTOM_PKGS[@]}"
    do
      log "Fetching ${key} from ${CUSTOM_PKGS[$key]}"
      wget -nv "${CUSTOM_PKGS[$key]}" -P "${ROOTFS}"/volumio/customPkgs/
    done
  fi


  # Prepare Images
  start_img=$(date +%s)
  BUILDDATE=$(date -I)
  IMG_FILE="Volumio-${VERSION}-${BUILDDATE}-${DEVICE}.img"

  # shellcheck source=scripts/makeimage.sh
  source "${SRC}/scripts/makeimage.sh"

  end_img=$(date +%s)
  time_it "$end_img" "$start_img"
  log "Image ${IMG_FILE} Created" "okay" "$TIME_STR"
  log "Compressing image"
  start_zip=$(date +%s)
  ZIP_FILE=${IMG_FILE%.*}.zip
  zip "${ZIP_FILE}" "${IMG_FILE}"*
  end_zip=$(date +%s)
  time_it "$end_zip" "$start_zip"
  log "Image ${ZIP_FILE} Created" "okay" "$TIME_STR"
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
