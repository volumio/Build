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
  log "Mounting temp devices for chroot" "info"
  mount /proc "$rootfs/proc" -t proc
  mount /sys "$rootfs/sys" -t sysfs
  mount chdev "$rootfs/dev" -t devtmpfs || mount --bind /dev "$rootfs/dev"
  mount chpts "$rootfs/dev/pts" -t devpts

  # mount /dev "$rootfs/dev" -o bind
  # Change the prompt so we know
  export PS1="(chroot) $PS1"
}

unmount_chroot(){
  log "Unmounting chroot temporary devices"
  umount -l "$rootfs/dev"  || log "umount dev failed" "wrn"
  umount -l "$rootfs/proc" || log "umount proc failed" "wrn"
  umount -l "$rootfs/sys"  || log "umount sys failed" "wrn"

  # Setting up cgmanager under chroot/qemu leaves a mounted fs behind, clean it up
  if [[ -d "$rootfs/run/cgmanager/fs" ]]; then
    umount -l "$rootfs/run/cgmanager/fs" || log "unmount cgmanager failed" "wrn"
  fi
}

exit_error () {
  log "Build script failed!!" "err"
  # Check if there are any mounts that need cleaning up
  # If dev is mounted, the rest should also be mounted (right?)
  if isMounted "$rootfs/dev"; then
    unmount_chroot
  fi
}

trap exit_error INT ERR

#$1 = ${BUILD} $2 = ${VERSION} $3 = ${DEVICE}"
function check_os_release {
  ## This shouldn't be required anymore - we pack the rootfs tarball at base level
  ARCH_BUILD=$1
  VERSION=$2
  DEVICE=$3
  os_release="build/${ARCH_BUILD}/root/etc/os-release"
  HAS_VERSION="grep -c VOLUMIO_VERSION $os_release"
  if $HAS_VERSION; then
    # os-release already has a VERSION number
    # remove prior version and hardware
    sed -i '/^\(VOLUMIO_TEST\|VOLUMIO_BUILD_DATE\)/d' $os_release
    # # cut the last 2 lines in case other devices are being built from the same rootfs
    # head -n -2 "build/${ARCH_BUILD}/root/etc/os-release" > "build/${ARCH_BUILD}/root/etc/tmp-release"
    # mv "build/${ARCH_BUILD}/root/etc/tmp-release" "build/${ARCH_BUILD}/root/etc/os-release"
  fi
  echo "VOLUMIO_VERSION=\"${VERSION}\"" >> $os_release
  echo "VOLUMIO_HARDWARE=\"${DEVICE}\"" >> $os_release
}

#Check the number of arguments. If none are passed, print help and exit.
NUMARGS=$#
if [ "$NUMARGS" -eq 0 ]; then
  HELP
fi

while getopts b:v:d:l:p:t:e:h: FLAG; do
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
    l)
      #Create docker layer
      CREATE_DOCKER_LAYER=1
      DOCKER_REPOSITORY_NAME=$OPTARG
      ;;
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
LOG_DIR=$SRC/logging/build_"$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$LOG_DIR"
# But it's annoying if root needs to delete it, soo
chown -R :users "$LOG_DIR"/

if [ -z "${VARIANT}" ]; then
  log "Setting default Volumio variant"
  VARIANT="volumio"
fi

if [ -n "$BUILD" ]; then
  log "Creating $BUILD rootfs" "info"
  #TODO Check naming conventions!
  BASE="Debian"
  if [[ ! -f "$SUITE" ]]; then
    log "Defaulting to Debian" "" "Buster"
    SUITE="buster"
  fi

  if [ "$BUILD" = arm ] || [ "$BUILD" = arm-dev ]; then
    ARCH="armhf"
    BUILD="arm"
    BASE="Raspbian"
  elif [ "$BUILD" = armv7 ] || [ "$BUILD" = armv7-dev ]; then
    ARCH="armhf"
    BUILD="armv7"
  elif [ "$BUILD" = armv8 ] || [ "$BUILD" = armv8-dev ]; then
    ARCH="arm64"
    BUILD="armv8"
  elif [ "$BUILD" = x86 ] || [ "$BUILD" = x86-dev ]; then
    ARCH="i386"
    BUILD="x86"
  fi

  CONF="$SRC/recipes/base/$BUILD-$SUITE.conf"

  if [[ ! -f $CONF ]]; then
    log "No base system configuration file found" "wrn" "$(basename "$CONF")"
    exit 1
  fi

  log "Building ${BASE} System for ${BUILD} ($ARCH)" "info"

  # Setup output directory

  if [ -d "$SRC/build/$BUILD" ]; then
    log "$BUILD rootfs exists, cleaning it"
    rm -rf "$SRC/build/$BUILD"
  fi
  rootfs="$SRC/build/$BUILD/root"
  mkdir -p $rootfs

  log "Creating rootfs in <./build/$BUILD/root>"

  #### Build stage 0
  ### Multistrap
  log "Setting up Multistrap environment" "info"
  log "Preparing rootfs apt-config"
  DirEtc="$rootfs/etc/apt/"
  DirEtcparts="$DirEtc/apt.conf.d"
  DirEtctrustedparts="$DirEtc/trusted.gpg.d"

  mkdir -p ${DirEtcparts}
  mkdir -p ${DirEtctrustedparts}
  echo -e 'Dpkg::Progress-Fancy "1";\nAPT::Color "1";' > \
    ${DirEtcparts}/01progress

  log "Adding SecureApt keys to rootfs"
  for key in "${!SecureApt[@]}"
  do
    apt-key --keyring "${DirEtctrustedparts}/${key}" \
      adv --fetch-keys ${SecureApt[$key]}
  done

  log "Running multistrap for ${BUILD} (${ARCH})"
  # shellcheck disable=SC2069
  if ! multistrap -a "$ARCH" -f "$CONF"  2>&1 > $LOG_DIR/multistrap.log
  # if ! { multistrap -a "$ARCH" -f "$CONF" > /dev/null; } 2>&1
  then
    log "Multistrap failed. Exiting" "err"
    exit 1
  else
    end_multistrap=$(date +%s)
    time_it $end_multistrap $start
    log "Finished setting up Multistrap rootfs" "okay" "$time_str"
  fi


  log "Preparing for Volumio chroot configuration" "info"
  start_chroot=$(date +%s)

  if [ ! "$BUILD" = x86 ]; then
    log "Build for $BUILD platform, copying qemu"
    cp /usr/bin/qemu-arm-static "$rootfs/usr/bin/"
  fi

  cp scripts/volumio/volumioconfig.sh "$rootfs"
  cp scripts/helpers.sh "$rootfs"

  mount_chroot

  log 'Cloning Volumio Node Backend'
  mkdir "$rootfs/volumio"

  if [ -n "$PATCH" ]; then
    log "Cloning Volumio with all its history"
    git clone https://github.com/volumio/Volumio2.git "$rootfs/volumio"
  else
    git clone --depth 1 -b master --single-branch https://github.com/volumio/Volumio2.git "$rootfs/volumio"
  fi

  log 'Cloning Volumio UI'
  git clone --depth 1 -b dist --single-branch https://github.com/volumio/Volumio2-UI.git "$rootfs/volumio/http/www"

  log "Adding Volumio revision information to os-release"
  cat <<-EOF >> "$rootfs/etc/os-release"
	VOLUMIO_BUILD_VERSION=$(git rev-parse HEAD)
	VOLUMIO_FE_VERSION=$(git --git-dir "$rootfs/volumio/http/www/.git" rev-parse HEAD)
	VOLUMIO_BE_VERSION=$(git --git-dir "$rootfs/volumio/.git" rev-parse HEAD)
	VOLUMIO_ARCH=${BUILD}
	EOF
  # Clean up git repo
  rm -rf $rootfs/volumio/http/www/.git

  log "Configuring Volumio" "info"
  if [ ! "$BUILD" = x86 ]; then
    chroot "$rootfs" /bin/bash -x <<-EOF
	su -
	./volumioconfig.sh
	EOF
  else
    echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:' > /proc/sys/fs/binfmt_misc/register
    chroot "$rootfs" /volumioconfig.sh
  fi

  ###Dirty fix for mpd.conf TODO use volumio repo
  cp volumio/etc/mpd.conf "$rootfs/etc/mpd.conf"

  CUR_DATE=$(date)
  #Write some Version information
  log "Writing system information"
  cat <<-EOF >>  "build/${BUILD}/root/etc/os-release"
	VOLUMIO_VARIANT=\"${VARIANT}\"
	VOLUMIO_TEST=\"FALSE\"
	VOLUMIO_BUILD_DATE=\"${CUR_DATE}\"
	EOF

  unmount_chroot

  end_chroot=$(date +%s)
  time_it $end_chroot $start_chroot

  log "Base rootfs Installed" "okay" "$time_str"
  rm -f "$rootfs/volumioconfig.sh"

  log "Running Volumio configuration script on rootfs" "info"
  bash scripts/volumio/configure.sh -b "$BUILD"

  log "Volumio rootfs created" "okay"
  # Bundle up the base rootfs
  log "Creating base system rootfs tarball"
  # https://superuser.com/questions/168749/is-there-a-way-to-see-any-tar-progress-per-file/665181#665181
  rootfs_tarball="$SRC/build/$BUILD"_rootfs
  tar cp --xattrs --directory=build/${BUILD}/ \
    --exclude='./dev/*' --exclude='./proc/*' \
    --exclude='./run/*' --exclude='./tmp/*' \
    --exclude='./sys/*' . \
    | pv -p -b -r -s "$(du -sb build/${BUILD}/ | cut -f1)" -N "$rootfs_tarball" | lz4 -c > $rootfs_tarball.lz4
  log "Created ${BUILD}_rootfs.lz4" "okay"
else
  use_rootfs_tarball=yes
fi


## Stage two Device specific

if [[ -n "$DEVICE" ]]; then
  DEV_CONFIG="$SRC/recipes/boards/${DEVICE}.sh"
  if [[ -f $DEV_CONFIG ]]; then
    # shellcheck source=/dev/null
    source $DEV_CONFIG
    log "Preparing an image for ${DEVICE} using $BASE - $BUILD"
    if [[ $use_rootfs_tarball == yes ]]; then
      log "Trying to use prior base system" "info"
      rootfs_tarball="$SRC/build/$BUILD"_rootfs
      [[ ! -f ${rootfs_tarball}.lz4 ]] && log "Couldn't find prior base system!" "err" && exit 1
      mkdir ./build/${BUILD}
      pv -p -b -r -c -N "[ .... ] $rootfs_tarball" "${rootfs_tarball}.lz4" \
        | lz4 -dc \
        | tar xp --xattrs -C ./build/${BUILD}
    fi
  else
    log "No configuration found for $DEVICE" "err"
    exit 1
  fi

  ## How do we work with this -
  #TODO
  if [ -n "$PATCH" ]; then
    log "Copying Patch to Rootfs"
    cp -rp "$PATCH"  "$rootfs/"
  else
    log "No patches found, defaulting to Volumio rootfs"
    PATCH='volumio'
  fi

  ## Stage two Image creation


  ## Prepare Images
  start_img=$(date +%s)
  case "$DEVICE" in
    pi) log 'Writing Raspberry Pi Image File' "info"
      check_os_release "arm" "$VERSION" "$DEVICE"
      bash scripts/raspberryimage.sh -v "$VERSION" -p "$PATCH"
      ;;
    cuboxi) log 'Writing Cubox-i Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/cuboxiimage.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    odroidc1) log 'Writing Odroid-C1/C1+ Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/odroidc1image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    odroidc2) log 'Writing Odroid-C2 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/odroidc2image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    odroidn2) log 'Writing Odroid-N2 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/odroidn2image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    odroidxu4) log 'Writing Odroid-XU4 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/odroidxu4image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    odroidx2) log 'Writing Odroid-X2 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/odroidx2image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    sparky) log 'Writing Sparky Image File' "info"
      check_os_release "arm" "$VERSION" "$DEVICE"
      bash scripts/sparkyimage.sh -v "$VERSION" -p "$PATCH" -a arm
      ;;
    bbb) log 'Writing BeagleBone Black Image File' "info"
      check_os_release "arm" "$VERSION" "$DEVICE"
      bash scripts/bbbimage.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    udooneo) log 'Writing UDOO NEO Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/udooneoimage.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    udooqdl) log 'Writing UDOO Quad/Dual Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/udooqdlimage.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    pine64) log 'Writing Pine64 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      # this will be changed to armv8 once the volumio packges have been re-compiled for aarch64
      bash scripts/pine64image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    nanopi64) log 'Writing NanoPI A64 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/nanopi64image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    bpim2u) log 'Writing BPI-M2U Image File' "info"
      check_os_release "arm" "$VERSION" "$DEVICE"
      bash scripts/bpim2uimage.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    bpipro) log 'Writing Banana PI PRO Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/bpiproimage.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    armbian_*)
      log 'Writing armbian-based Image File' "info"
      check_os_release "arm" "$VERSION" "$DEVICE"
      bash scripts/armbianimage.sh -v "$VERSION" -d "$DEVICE" -p "$PATCH"
      ;;
    tinkerboard) log 'Writing Ausus Tinkerboard Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/tinkerimage.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    sopine64) log 'Writing Sopine64 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/sopine64image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    rock64) log 'Writing Rock64 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/rock64image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    voltastream0) log 'Writing PV Voltastream0 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/vszeroimage.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    aml805armv7) log 'Writing Amlogic S805 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/aml805armv7image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    aml812armv7) log 'Writing Amlogic S812 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/aml812armv7image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    aml9xxxarmv7) log 'Writing AmlogicS9xxx Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/aml9xxxarmv7image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    orangepione|orangepilite|orangepipc) log 'Writing OrangePi Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/orangepiimage.sh -v "$VERSION" -p "$PATCH" -d "$DEVICE"
      ;;
    rockpis) log 'Writing ROCK Pi S Image File' "info"
      check_os_release "armv8" "$VERSION" "$DEVICE"
      # bash scripts/rockpisimage.sh -v "$VERSION" -p "$PATCH" -d "$DEVICE" -a armv8
      ;;
    x86) log 'Writing x86 Image File' "info"
      check_os_release "x86" "$VERSION" "$DEVICE"
      bash scripts/x86image.sh -v "$VERSION" -p "$PATCH";
      ;;
    nanopineo2) log 'Writing NanoPi-NEO2 armv7 Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/nanopineo2image.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    nanopineo) log 'Writing NanoPi-NEO (Air) Image File' "info"
      check_os_release "armv7" "$VERSION" "$DEVICE"
      bash scripts/nanopineoimage.sh -v "$VERSION" -p "$PATCH" -a armv7
      ;;
    "") log 'No device specified' "wrn"
      ;;
    *) log Unknown/Unsupported device: $DEVICE "err"
      exit 1
      ;;
  esac

  end_img=$(date +%s)
  time_it $end_img $start_img
  log "Image ${IMG_FILE} Created" "okay" "$time_str"
else
  log "No device specified, only base rootfs created!" "wrn"
fi

end_build=$(date +%s)
time_it $end_build $start

log "Cleaning up rootfs.." "info" "build/$BUILD/"
rm -r build/$BUILD/ || log "Couldn't clean rootfs" "wrn"

log "Volumio Builder finished: \
$([[ -n $BUILD ]] && echo "${yellow}BUILD=${standout}${BUILD}${normal} ")\
$([[ -n $DEVICE ]] && echo "${yellow}DEVICE=${standout}${DEVICE}${normal}  ")\
$([[ -n $VERSION ]] && echo "${yellow}VERSION=${standout}${VERSION}${normal} ")\
${normal}" "okay" "$time_str"


# Looks to be an artifact of some customization of a build script - lets ignore it for now.
# #When the tar is created we can build the docker layer
# if [ "$CREATE_DOCKER_LAYER" = 1 ]; then
#   log 'Creating docker layer' "info"
#   DOCKER_UID="$(sudo docker import "VolumioRootFS$VERSION.tar.gz" "$DOCKER_REPOSITORY_NAME")"
#   log "$DOCKER_UID" "okay"
# fi
