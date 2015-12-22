#!/bin/bash
#Volumio Image Builder
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
  echo -e \\n"Help documentation for Volumio Image Builder"\\n
  echo -e "Basic usage: ./build.sh -b -d all -v 2.0"\\n
  echo "Switches:"
  echo "-b      --Build system with Multistrap, use arm or x86 to select architecture"
  echo "-d      --Create Image for Specific Devices. Usage: all (all), pi, udoo, cuboxi, bbb, cubietruck, compulab"
  echo "-l      --Create docker layer. Docker Repository name as as argument"
  echo "-v      --Version"
  echo -e "Example: Build a Raspberry PI image from scratch, version 2.0 : ./build.sh -b arm -d pi -v 2.0 -l reponame "\\n
  exit 1
}

#$1 = ${BUILD} $2 = ${VERSION} $3 = ${DEVICE}"
function check_os_release {
  ARCH_BUILD=$1
  HAS_VERSION=$(grep -c VOLUMIO_VERSION build/${ARCH_BUILD}/root/etc/os-release)
  VERSION=$2
  DEVICE=$3

  if [ "$HAS_VERSION" -eq "0" ]; then
    echo "VOLUMIO_VERSION=\"${VERSION}\"" >> build/${ARCH_BUILD}/root/etc/os-release
    echo "VOLUMIO_HARDWARE=\"${DEVICE}\"" >> build/${ARCH_BUILD}/root/etc/os-release
  fi
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


if [ -n "$BUILD" ]; then
  if [ "$BUILD" = arm ]; then
    ARCH="armhf"
    echo "Building ARM Base System"
  elif [ "$BUILD" = x86 ]; then
    echo 'Building X86 Base System' 
    ARCH="i386"
  fi
  if [ -d build ]
    then 
    echo "Build folder exist, cleaning it"
    rm -rf build/*
  else
    echo "Creating build folder"
    sudo mkdir build
  fi

  mkdir build/$BUILD
  mkdir build/$BUILD/root
  multistrap -a $ARCH -f recipes/$BUILD.conf
  if [ "$BUILD" = arm ]; then
    cp /usr/bin/qemu-arm-static build/arm/root/usr/bin/
  fi
  cp scripts/volumioconfig.sh build/$BUILD/root
  mount /dev build/$BUILD/root/dev -o bind
  mount /proc build/$BUILD/root/proc -t proc
  mount /sys build/$BUILD/root/sys -t sysfs
  echo 'Cloning Volumio'
  mkdir build/$BUILD/root/volumio
  git clone https://github.com/volumio/Volumio2.git build/$BUILD/root/volumio
  if [ "$BUILD" = arm ]; then
  chroot build/arm/root /bin/bash -x <<'EOF'
su -
./volumioconfig.sh
EOF
  elif [ "$BUILD" = x86 ]; then
    chroot build/x86/root /volumioconfig.sh
  fi

  echo "Adding information in os-release"
  echo '

' >> build/${BUILD}/root/etc/os-release

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
  sh scripts/configure.sh -b $BUILD
fi

if [ -n "$PATCH" ]; then
  echo "Copying Patch to Rootfs" 
  cp -rp $PATCH  build/$BUILD/root/
else
  PATCH='volumio'
fi


if [ "$DEVICE" = pi ]; then
  echo 'Writing Raspberry Pi Image File'
  check_os_release "arm" $VERSION $DEVICE
  sh scripts/raspberryimage.sh -v $VERSION -p $PATCH; 
fi
if [ "$DEVICE" = udoo ]; then
  echo 'Writing UDOO Image File'
  sh scripts/udooimage.sh -v $VERSION ;
fi
if [ "$DEVICE" = cuboxi ]; then
  echo 'Writing Cubox-i Image File'
  sh scripts/cuboxiimage.sh -v $VERSION; 
fi
if  [ "$DEVICE" = odroidc ]; then
  echo 'Writing OdroidCx Image File'
  check_os_release "arm" $VERSION $DEVICE
  sh scripts/odroidcimage.sh -v $VERSION -p $PATCH; 
fi
if  [ "$DEVICE" = odroidxu4 ]; then
  echo 'Writing OdroidCx Image File'
  check_os_release "arm" $VERSION $DEVICE
  sh scripts/odroidxu4image.sh -v $VERSION -p $PATCH; 
fi
if  [ "$DEVICE" = udooneo ]; then
  echo 'Writing UDOO NEO Image File'
  check_os_release "arm" $VERSION $DEVICE
  sh scripts/udooneoimage.sh -v $VERSION -p $PATCH; 
fi

if [ "$DEVICE" = x86 ]; then
  echo 'Writing x86 Image File'
  check_os_release "x86" $VERSION $DEVICE
  sh scripts/x86.sh -v $VERSION -p $PATCH; 
fi

#When the tar is created we can build the docker layer
if  [ "$CREATE_DOCKER_LAYER" = 1 ]; then
  echo 'Creating docker layer'
  DOCKER_UID="$(sudo docker import VolumioRootFS$VERSION.tar.gz $DOCKER_REPOSITORY_NAME)"
  echo $DOCKER_UID
fi
