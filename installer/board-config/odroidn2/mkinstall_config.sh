#!/bin/bash

# Device Info Odroid N2/N2+
DEVICEBASE="odroid"
BOARDFAMILY="odroidn2"
PLATFORMREPO="https://github.com/volumio/platform-odroid.git"
BUILD="armv7"
NONSTANDARD_REPO=no	# yes requires "non_standard_repo() function in make.sh 
LBLBOOT="BOOT"
LBLIMAGE="volumio"
LBLDATA="volumio_data"

# Partition Info
BOOT_TYPE=msdos			# msdos or gpt   
BOOT_START=1
BOOT_END=64
IMAGE_END=3800
BOOT=/mnt/boot
BOOTDELAY=1
BOOTDEV="mmcblk1"
BOOTPART=/dev/mmcblk1p1
BOOTCONFIG=boot.ini

TARGETBOOT="/dev/mmcblk0p1"
TARGETDEV="/dev/mmcblk0"
TARGETDATA="/dev/mmcblk0p3"
TARGETIMAGE="/dev/mmcblk0p2"
HWDEVICE=
USEKMSG="yes"
UUIDFMT="yes"			# yes|no (actually, anything non-blank)
FACTORYCOPY="yes"


# Modules to load (as a blank separated string array)
MODULES="nls_cp437"

# Additional packages to install (as a blank separated string)
#PACKAGES=""

# initramfs type
RAMDISK_TYPE=image		# image or gzip (ramdisk image = uInitrd, gzip compressed = volumio.initrd) 

non_standard_repo()
{
   :
}

fetch_bootpart_uuid()
{
   :
}

is_dataquality_ok()
{
   return 0
}

write_device_files()
{
   cp ${PLTDIR}/${BOARDFAMILY}/boot/Image.gz $ROOTFSMNT/boot
   cp ${PLTDIR}/${BOARDFAMILY}/boot/boot.ini $ROOTFSMNT/boot
   cp ${PLTDIR}/${BOARDFAMILY}/boot/config.ini $ROOTFSMNT/boot

   mkdir /mnt/volumio/rootfs/boot/amlogic
   cp -R ${PLTDIR}/${BOARDFAMILY}/boot/amlogic/* $ROOTFSMNT/boot/amlogic
}

write_device_bootloader()
{
   dd if=${PLTDIR}/${BOARDFAMILY}/uboot/u-boot.bin of=${LOOP_DEV} conv=fsync bs=512 seek=1
}

copy_device_bootloader_files()
{
   mkdir /mnt/volumio/rootfs/boot/u-boot
   cp ${PLTDIR}/${BOARDFAMILY}/uboot/u-boot.bin $ROOTFSMNT/boot/u-boot
}

write_boot_parameters()
{
   sed -i "s/%%VOLUMIO-PARAMS%%/loglevel=0/g" $ROOTFSMNT/boot/boot.ini
}




