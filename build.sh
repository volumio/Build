#!/bin/bash
#Volumio Image Builder
#
#

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
  echo "-v      --Version"
  echo -e "Example: Build a Raspberry PI image from scratch, version 2.0 : ./build.sh -b -d pi -v 2.0 "\\n
  exit 1
}

#Check the number of arguments. If none are passed, print help and exit.
NUMARGS=$#
if [ $NUMARGS -eq 0 ]; then
  HELP
fi

while getopts b:v:d:e FLAG; do
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


if [ "$BUILD" = arm ]; then
ARCH="armhf"
echo "Building ARM Base System"
elif [ "$BUILD" = x86 ]; then
echo 'Building X86 Base System' 
ARCH="i386"
fi
mkdir build
mkdir build/$BUILD
mkdir build/$BUILD/root
multistrap -a $ARCH -f recipes/$BUILD.conf
if [ "$BUILD" = arm ]; then
cp /usr/bin/qemu-arm-static build/arm/root/usr/bin/
fi
cp scripts/firstconfig.sh build/$BUILD/root
mount /dev build/$BUILD/root/dev -o bind
mount /proc build/$BUILD/root/proc -t proc
mount /sys build/$BUILD/root/sys -t sysfs
chroot build/$BUILD/root /bin/bash -x <<'EOF'
su -
./firstconfig.sh
EOF
echo "Base System Installed"
rm build/$BUILD/root/firstconfig.sh
echo "Unmounting Temp devices"
umount -l build/$BUILD/root/dev 
umount -l build/$BUILD/root/proc 
umount -l build/$BUILD/root/sys 
sh scripts/configure.sh -b $BUILD


if [ "$DEVICE" = pi ]; then
echo 'Writing Rasoberry Pi Image File'
sh scripts/raspberryimage.sh -v $VERSION; 
fi
if [ "$DEVICE" = udoo ]; then
echo 'Writing UDOO Image File'
sh scripts/udooimage.sh -v $VERSION ;
fi
if  [ "$DEVICE" = cuboxi ]; then
echo 'Writing Cubox-i Image File'
sh scripts/cuboxiimage.sh -v $VERSION; 
fi

