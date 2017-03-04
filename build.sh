#!/bin/bash
# Volumio Image Builder
# Copyright Michelangelo Guarise - Volumio.org
#
# TODO: Add gé credits
#
# Dependencies:
# parted squashfs-tools dosfstools multistrap qemu binfmt-support qemu-user-static kpartx

#Set fonts for Help.
NORM=`tput sgr0`
BOLD=`tput bold`
REV=`tput smso`

ARCH=none
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
              bpim2u, bpipro
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
  HAS_VERSION=$(grep -c VOLUMIO_VERSION build/${ARCH_BUILD}/root/etc/os-release)
  VERSION=$2
  DEVICE=$3

  if [ "$HAS_VERSION" -ne "0" ]; then
    # os-release already has a VERSION number
    # cut the last 2 lines in case other devices are being built from the same rootfs
	head -n -2 build/${ARCH_BUILD}/root/etc/os-release > build/${ARCH_BUILD}/root/etc/tmp-release
	mv build/${ARCH_BUILD}/root/etc/tmp-release build/${ARCH_BUILD}/root/etc/os-release
  fi
  echo "VOLUMIO_VERSION=\"${VERSION}\"" >> build/${ARCH_BUILD}/root/etc/os-release
  echo "VOLUMIO_HARDWARE=\"${DEVICE}\"" >> build/${ARCH_BUILD}/root/etc/os-release
  echo "VOLUMIO_BUILD_VERSION=\"$(git rev-parse HEAD)\"" >> build/${ARCH_BUILD}/root/etc/os-release
}


#Check the number of arguments. If none are passed, print help and exit.
NUMARGS=$#
if [ $NUMARGS -eq 0 ]; then
  HELP
fi

while getopts b:v:d:l:p:e FLAG; do
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
    /?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      HELP
      ;;
  esac
done

shift $((OPTIND-1))

echo "Checking whether we are running as root"
if [ $(id -u) -ne 0 ]; then
  echo "Please run the build script as root"
  exit
fi

if [ -n "$BUILD" ]; then
  CONF=recipes/$BUILD.conf
  if [ "$BUILD" = arm ] || [ "$BUILD" = arm-dev ]; then
    ARCH="armhf"
	BUILD=arm
    echo "Building ARM Base System with Raspbian"
  elif [ "$BUILD" = armv7 ] || [ "$BUILD" = armv7-dev ]; then
    ARCH="armhf"
	BUILD="armv7"
    echo "Building ARMV7 Base System with Debian"
  elif [ "$BUILD" = armv8 ] || [ "$BUILD" = armv8-dev ]; then
    ARCH="arm64"
	BUILD="armv8"
    echo "Building ARMV8 (arm64) Base System with Debian"
  elif [ "$BUILD" = x86 ] || [ "$BUILD" = x86-dev ]; then
    echo 'Building X86 Base System with Debian'
    ARCH="i386"
	BUILD="x86"
  elif [ ! -f recipes/$BUILD.conf ]; then
    echo "Unexpected Base System architecture '$BUILD' - aborting."
    exit
  fi
  if [ -d build/$BUILD ]; then
    echo "Build folder exists, cleaning it"
    rm -rf build/$BUILD
  elif [ -d build ]; then
    echo "Build folder exists, leaving it"
  else
    echo "Creating build folder"
    mkdir build
  fi

  mkdir build/$BUILD
  mkdir build/$BUILD/root
  multistrap -a $ARCH -f $CONF
  if [ ! "$BUILD" = x86 ]; then
	echo "Build for arm/armv7/armv8 platform, copying qemu"
    cp /usr/bin/qemu-arm-static build/$BUILD/root/usr/bin/
  fi
  cp scripts/volumioconfig.sh build/$BUILD/root

  mount /dev build/$BUILD/root/dev -o bind
  mount /proc build/$BUILD/root/proc -t proc
  mount /sys build/$BUILD/root/sys -t sysfs

  echo 'Cloning Volumio Node Backend'
  mkdir build/$BUILD/root/volumio
  git clone --depth 1 -b master --single-branch https://github.com/volumio/Volumio2.git build/$BUILD/root/volumio
  echo "VOLUMIO_BE_VERSION=\"$(git --git-dir /volumio/.git rev-parse HEAD)\"" >> os-release
  echo 'Cloning Volumio UI'
  git clone --depth 1 -b dist --single-branch https://github.com/volumio/Volumio2-UI.git build/$BUILD/root/volumio/http/www
  echo "VOLUMIO_FE_VERSION=\"$(git --git-dir /volumio/http/www/.git rev-parse HEAD)\"" >> os-release

  if [ ! "$BUILD" = x86 ]; then
  chroot build/$BUILD/root /bin/bash -x <<'EOF'
su -
./volumioconfig.sh
EOF
  else 
echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:' > /proc/sys/fs/binfmt_misc/register
    chroot build/$BUILD/root /volumioconfig.sh
  fi

  echo "Adding information in os-release"
  echo '

' >> build/$BUILD/root/etc/os-release

  echo "Base System Installed"
  rm build/$BUILD/root/volumioconfig.sh
  ###Dirty fix for mpd.conf TODO use volumio repo
  cp volumio/etc/mpd.conf build/$BUILD/root/etc/mpd.conf

  CUR_DATE=$(date)
  #Write some Version informations
  echo "Writing system information"
  echo "VOLUMIO_VARIANT=\"volumio\"
VOLUMIO_TEST=\"FALSE\"
VOLUMIO_BUILD_DATE=\"${CUR_DATE}\"
" >> build/${BUILD}/root/etc/os-release

  echo "Unmounting Temp devices"
  umount -l build/$BUILD/root/dev
  umount -l build/$BUILD/root/proc
  umount -l build/$BUILD/root/sys
  # Setting up cgmanager under chroot/qemu leaves a mounted fs behind, clean it up
  umount -l build/$BUILD/root/run/cgmanager/fs
  sh scripts/configure.sh -b $BUILD
fi

if [ -n "$PATCH" ]; then
  echo "Copying Patch to Rootfs"
  cp -rp $PATCH  build/$BUILD/root/
else
  PATCH='volumio'
fi

case $DEVICE in
  pi) echo 'Writing Raspberry Pi Image File'
      check_os_release "arm" $VERSION $DEVICE
      sh scripts/raspberryimage.sh -v $VERSION -p $PATCH
      ;;
  cuboxi) echo 'Writing Cubox-i Image File'
      check_os_release "armv7" $VERSION $DEVICE
      sh scripts/cuboxiimage.sh -v $VERSION -p $PATCH -a armv7
      ;;
  odroidc1) echo 'Writing Odroid-C1/C1+ Image File'
      check_os_release "armv7" $VERSION $DEVICE
      sh scripts/odroidc1image.sh -v $VERSION -p $PATCH -a armv7
      ;;
  odroidc2) echo 'Writing Odroid-C2 Image File'
      check_os_release "armv7" $VERSION $DEVICE
# this will be changed to armv8 once the volumio packges have been re-compiled for aarch64
      sh scripts/odroidc2image.sh -v $VERSION -p $PATCH -a armv7
      ;;
  odroidxu4) echo 'Writing Odroid-XU4 Image File'
      check_os_release "armv7" $VERSION $DEVICE
      sh scripts/odroidxu4image.sh -v $VERSION -p $PATCH -a armv7
      ;;
  odroidx2) echo 'Writing Odroid-X2 Image File'
      check_os_release "armv7" $VERSION $DEVICE
      sh scripts/odroidx2image.sh -v $VERSION -p $PATCH -a armv7
      ;;
  sparky) echo 'Writing Sparky Image File'
      check_os_release "arm" $VERSION $DEVICE
      sh scripts/sparkyimage.sh -v $VERSION -p $PATCH -a arm
      ;;
  bbb) echo 'Writing BeagleBone Black Image File'
      check_os_release "arm" $VERSION $DEVICE
      sh scripts/bbbimage.sh -v $VERSION -p $PATCH -a armv7
      ;;
  udooneo) echo 'Writing UDOO NEO Image File'
      check_os_release "armv7" $VERSION $DEVICE
      sh scripts/udooneoimage.sh -v $VERSION -p $PATCH -a armv7
      ;;
  udooqdl) echo 'Writing UDOO Quad/Dual Image File'
      check_os_release "armv7" $VERSION $DEVICE
      sh scripts/udooqdlimage.sh -v $VERSION -p $PATCH -a armv7
      ;;
  pine64) echo 'Writing Pine64 Image File'
      check_os_release "armv7" $VERSION $DEVICE
# this will be changed to armv8 once the volumio packges have been re-compiled for aarch64
      sh scripts/pine64image.sh -v $VERSION -p $PATCH -a armv7
      ;;
  bpim2u) echo 'Writing BPI-M2U Image File'
      check_os_release "arm" $VERSION $DEVICE
      sh scripts/bpim2uimage.sh -v $VERSION -p $PATCH -a armv7
      ;;
  bpipro) echo 'Writing Banana PI PRO Image File'
      check_os_release "armv7" $VERSION $DEVICE
      sh scripts/bpiproimage.sh -v $VERSION -p $PATCH -a armv7
      ;;    
  armbian_*)
      echo 'Writing armbian-based Image File'
      check_os_release "arm" $VERSION $DEVICE
      sh scripts/armbianimage.sh -v $VERSION -d "$DEVICE" -p $PATCH
      ;;
  x86) echo 'Writing x86 Image File'
      check_os_release "x86" $VERSION $DEVICE
      sh scripts/x86image.sh -v $VERSION -p $PATCH;
      ;;
esac

#When the tar is created we can build the docker layer
if  [ "$CREATE_DOCKER_LAYER" = 1 ]; then
  echo 'Creating docker layer'
  DOCKER_UID="$(sudo docker import VolumioRootFS$VERSION.tar.gz $DOCKER_REPOSITORY_NAME)"
  echo $DOCKER_UID
fi
