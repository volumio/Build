#!/bin/bash
#Volumio Image Builder
#
#

#Initialize variables to default values.
BUILD=false

#Set fonts for Help.
NORM=`tput sgr0`
BOLD=`tput bold`
REV=`tput smso`

#Help function
function HELP {
  echo -e \\n"Help documentation for Volumio Image Builder"\\n
  echo -e "Basic usage: ./build.sh -b -d all -v 2.0"\\n
  echo "Switches:"
  echo "-b      --Build system with Multistrap, optional but required upon first usage"
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

while getopts :v:d:be FLAG; do
  case $FLAG in
    b)  
      BUILD=true
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

if [ "$BUILD" = true ]; then
echo "Building $VERSION base system"
echo "Executing Multistrap"
echo "Building Base Jessie System"
mkdir build
mkdir build/root
multistrap -a armhf -f conf/minimal.conf
cp /usr/bin/qemu-arm-static build/root/usr/bin/
cp scripts/firstconfig.sh build/root
mount /dev build/root/dev -o bind
mount /proc build/root/proc -t proc
mount /sys build/root/sys -t sysfs
chroot build/root /bin/bash -x <<'EOF'
su -
./firstconfig.sh 
EOF
echo "Base System Installed"
rm build/root/firstconfig.sh
echo "Unmounting Temp devices"
umount -l build/root/dev 
umount -l build/root/proc 
umount -l build/root/sys 
sh scripts/configure.sh
<<<<<<< HEAD

else 
echo 'Writing UDOO Image File'
sh scripts/udooimage.sh -v 1.5 -d UDOO

 

