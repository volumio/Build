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
source "${SRC}"/scripts/helpers.sh
export -f log
export -f time_it

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

#$1 = ${BUILD} $2 = ${VERSION} $3 = ${DEVICE}"
function check_os_release {
  ARCH_BUILD=$1
  VERSION=$2
  DEVICE=$3
  HAS_VERSION="grep -c VOLUMIO_VERSION build/${ARCH_BUILD}/root/etc/os-release"

  if $HAS_VERSION; then
    # os-release already has a VERSION number
    # cut the last 2 lines in case other devices are being built from the same rootfs
    head -n -2 "build/${ARCH_BUILD}/root/etc/os-release" > "build/${ARCH_BUILD}/root/etc/tmp-release"
    mv "build/${ARCH_BUILD}/root/etc/tmp-release" "build/${ARCH_BUILD}/root/etc/os-release"
  fi
  echo "VOLUMIO_VERSION=\"${VERSION}\"" >> "build/${ARCH_BUILD}/root/etc/os-release"
  echo "VOLUMIO_HARDWARE=\"${DEVICE}\"" >> "build/${ARCH_BUILD}/root/etc/os-release"
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
  exit
fi

start=$(date +%s)

if [ -z "${VARIANT}" ]; then
  VARIANT="volumio"
fi

if [ -n "$BUILD" ]; then
  CONF="recipes/$BUILD.conf"
  if [ "$BUILD" = arm ] || [ "$BUILD" = arm-dev ]; then
    ARCH="armhf"
    BUILD="arm"
    log "Building ARM Base System with Raspbian" "info"
  elif [ "$BUILD" = armv7 ] || [ "$BUILD" = armv7-dev ]; then
    ARCH="armhf"
    BUILD="armv7"
    log "Building ARMV7 Base System with Debian" "info"
    CONF="recipes/$BUILD-$SUITE.conf"
  elif [ "$BUILD" = armv8 ] || [ "$BUILD" = armv8-dev ]; then
    ARCH="arm64"
    BUILD="armv8"
    CONF="recipes/$BUILD-$SUITE.conf"
    log "Building ARMV8 (arm64) Base System with Debian" "info"
  elif [ "$BUILD" = x86 ] || [ "$BUILD" = x86-dev ]; then
    log 'Building X86 Base System with Debian' "info"
    ARCH="i386"
    BUILD="x86"
  elif [ ! -f recipes/$BUILD.conf ]; then
    log "Unexpected Base System architecture '$BUILD' - aborting." "info"
    exit
  fi

  # Setup output directory
  if [ -d "build/$BUILD" ]; then
    log "Build folder exists, cleaning it"
    rm -rf "build/$BUILD"
  elif [ -d build ]; then
    log "Build folder exists, leaving it"
  else
    log "Creating build folder"
    mkdir build
  fi

  mkdir "build/$BUILD"
  mkdir "build/$BUILD/root"


  ### Multistrap
  #TODO Move all such config to a central location
  declare -A SecureApt=(
    [nodesource.gpg]="https://deb.nodesource.com/gpgkey/nodesource.gpg.key"  \
      [debian_10.gpg]="https://ftp-master.debian.org/keys/archive-key-10.asc" \
    )

  log "Setting up Multistrap environment" "info"
  log "Preparing rootfs apt-config"
  DirEtc="build/$BUILD/root/etc/apt/"
  DirEtcparts="${DirEtc}/apt.conf.d"
  DirEtctrustedparts="${DirEtc}/trusted.gpg.d"

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

  log "Running multistrap for ${ARCH}"
  # shellcheck disable=SC2069
  if ! multistrap -a "$ARCH" -f "$CONF"  2>&1 > /dev/null
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
    log "Build for arm/armv7/armv8 platform, copying qemu"
    cp /usr/bin/qemu-arm-static "build/$BUILD/root/usr/bin/"
  fi

  cp scripts/volumioconfig.sh "build/$BUILD/root"
  cp scripts/helpers.sh "build/$BUILD/root"

  #TODO Trap this!
  log "Mounting temp devices for chroot" "info"
  mount /dev "build/$BUILD/root/dev" -o bind
  mount /proc "build/$BUILD/root/proc" -t proc
  mount /sys "build/$BUILD/root/sys" -t sysfs


  log 'Cloning Volumio Node Backend'
  mkdir "build/$BUILD/root/volumio"

  if [ -n "$PATCH" ]; then
    log "Cloning Volumio with all its history"
    git clone https://github.com/volumio/Volumio2.git build/$BUILD/root/volumio
  else
    git clone --depth 1 -b master --single-branch https://github.com/volumio/Volumio2.git build/$BUILD/root/volumio
  fi

  log 'Cloning Volumio UI'
  git clone --depth 1 -b dist --single-branch https://github.com/volumio/Volumio2-UI.git "build/$BUILD/root/volumio/http/www"

  log "Adding Volumio revision information to os-release"
  {
    echo "VOLUMIO_BUILD_VERSION=\"$(git rev-parse HEAD)\""
    echo "VOLUMIO_FE_VERSION=\"$(git --git-dir "build/$BUILD/root/volumio/http/www/.git" rev-parse HEAD)\""
    echo "VOLUMIO_BE_VERSION=\"$(git --git-dir "build/$BUILD/root/volumio/.git" rev-parse HEAD)\""
    echo "VOLUMIO_ARCH=\"${BUILD}\""
  } >> "build/$BUILD/root/etc/os-release"
  rm -rf build/$BUILD/root/volumio/http/www/.git

  if [ ! "$BUILD" = x86 ]; then
    chroot "build/$BUILD/root" /bin/bash -x <<'EOF'
su -
./volumioconfig.sh
EOF
  else
    echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:' > /proc/sys/fs/binfmt_misc/register
    chroot "build/$BUILD/root" /volumioconfig.sh
  fi

  ###Dirty fix for mpd.conf TODO use volumio repo
  cp volumio/etc/mpd.conf "build/$BUILD/root/etc/mpd.conf"

  CUR_DATE=$(date)
  #Write some Version information
  log "Writing system information"
  echo "VOLUMIO_VARIANT=\"${VARIANT}\"
VOLUMIO_TEST=\"FALSE\"
VOLUMIO_BUILD_DATE=\"${CUR_DATE}\"
  " >> "build/${BUILD}/root/etc/os-release"

  log "Unmounting Temp devices"
  umount -l "build/$BUILD/root/dev"
  umount -l "build/$BUILD/root/proc"
  umount -l "build/$BUILD/root/sys"
  # Setting up cgmanager under chroot/qemu leaves a mounted fs behind, clean it up
  [ -d "build/$BUILD/root/run/cgmanager/fs" ] && umount -l "build/$BUILD/root/run/cgmanager/fs"

  end_chroot=$(date +%s)
  time_it $end_chroot $start_chroot

  log "Base rootfs Installed" "okay" "$time_str"
  rm -f "build/$BUILD/root/volumioconfig.sh"

  log "Running Volumio configuration script on rootfs" "info"
  bash scripts/configure.sh -b "$BUILD"

else
  log "Using existing rootfs" "okay"
fi


if [ -n "$PATCH" ]; then
  log "Copying Patch to Rootfs"
  cp -rp "$PATCH"  "build/$BUILD/root/"
else
  log "Building default image"
  PATCH='volumio'
fi


## Prepare Images

case "$DEVICE" in
  pi) log 'Writing Raspberry Pi Image File' "info"
    check_os_release "arm" "$VERSION" "$DEVICE"
    sh scripts/raspberryimage.sh -v "$VERSION" -p "$PATCH"
    ;;
  cuboxi) log 'Writing Cubox-i Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/cuboxiimage.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  odroidc1) log 'Writing Odroid-C1/C1+ Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/odroidc1image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  odroidc2) log 'Writing Odroid-C2 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/odroidc2image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  odroidn2) log 'Writing Odroid-N2 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/odroidn2image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  odroidxu4) log 'Writing Odroid-XU4 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/odroidxu4image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  odroidx2) log 'Writing Odroid-X2 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/odroidx2image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  sparky) log 'Writing Sparky Image File' "info"
    check_os_release "arm" "$VERSION" "$DEVICE"
    sh scripts/sparkyimage.sh -v "$VERSION" -p "$PATCH" -a arm
    ;;
  bbb) log 'Writing BeagleBone Black Image File' "info"
    check_os_release "arm" "$VERSION" "$DEVICE"
    sh scripts/bbbimage.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  udooneo) log 'Writing UDOO NEO Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/udooneoimage.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  udooqdl) log 'Writing UDOO Quad/Dual Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/udooqdlimage.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  pine64) log 'Writing Pine64 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    # this will be changed to armv8 once the volumio packges have been re-compiled for aarch64
    sh scripts/pine64image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  nanopi64) log 'Writing NanoPI A64 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/nanopi64image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  bpim2u) log 'Writing BPI-M2U Image File' "info"
    check_os_release "arm" "$VERSION" "$DEVICE"
    sh scripts/bpim2uimage.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  bpipro) log 'Writing Banana PI PRO Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/bpiproimage.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  armbian_*)
    log 'Writing armbian-based Image File' "info"
    check_os_release "arm" "$VERSION" "$DEVICE"
    sh scripts/armbianimage.sh -v "$VERSION" -d "$DEVICE" -p "$PATCH"
    ;;
  tinkerboard) log 'Writing Ausus Tinkerboard Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/tinkerimage.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  sopine64) log 'Writing Sopine64 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/sopine64image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  rock64) log 'Writing Rock64 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/rock64image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  voltastream0) log 'Writing PV Voltastream0 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/vszeroimage.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  aml805armv7) log 'Writing Amlogic S805 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/aml805armv7image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  aml812armv7) log 'Writing Amlogic S812 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/aml812armv7image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  aml9xxxarmv7) log 'Writing AmlogicS9xxx Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/aml9xxxarmv7image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  orangepione|orangepilite|orangepipc) log 'Writing OrangePi Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/orangepiimage.sh -v "$VERSION" -p "$PATCH" -d "$DEVICE"
    ;;
  rockpis) log 'Writing ROCK Pi S Image File' "info"
    check_os_release "armv8" "$VERSION" "$DEVICE"
    sh scripts/rockpisimage.sh -v "$VERSION" -p "$PATCH" -d "$DEVICE" -a armv8
    ;;
  x86) log 'Writing x86 Image File' "info"
    check_os_release "x86" "$VERSION" "$DEVICE"
    sh scripts/x86image.sh -v "$VERSION" -p "$PATCH";
    ;;
  nanopineo2) log 'Writing NanoPi-NEO2 armv7 Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/nanopineo2image.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  nanopineo) log 'Writing NanoPi-NEO (Air) Image File' "info"
    check_os_release "armv7" "$VERSION" "$DEVICE"
    sh scripts/nanopineoimage.sh -v "$VERSION" -p "$PATCH" -a armv7
    ;;
  "") log 'No device specified' "wrn"
    ;;
  *) log Unknown/Unsupported device: $DEVICE "err"
    exit 1
    ;;
esac

#When the tar is created we can build the docker layer
if [ "$CREATE_DOCKER_LAYER" = 1 ]; then
  log 'Creating docker layer' "info"
  DOCKER_UID="$(sudo docker import "VolumioRootFS$VERSION.tar.gz" "$DOCKER_REPOSITORY_NAME")"
  log "$DOCKER_UID" "okay"
fi
