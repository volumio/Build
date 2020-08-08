#!/bin/bash

# Device Info
DEVICEBASE="khadas"
BOARDFAMILY="vims"
PLATFORMREPO="https://github.com/volumio/platform-khadas.git"
BUILD="armv7"
NONSTANDARD_REPO=no	# yes requires "non_standard_repo() function in make.sh 
LBLBOOT="BOOT"
LBLIMAGE="volumio"
LBLDATA="volumio_data"

# Partition Info
BOOT_TYPE=msdos			# msdos or gpt   
BOOT_START=16
BOOT_END=80
IMAGE_END=2580
BOOT=/mnt/boot
BOOTDELAY=1
BOOTDEV="mmcblk1"
BOOTPART=/dev/mmcblk1p1
BOOTCONFIG=env.system.txt

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
echo "[info] replace BOOTPART device by ${FLASH_PART} UUID value"
UUIDBOOT=$(blkid -s UUID -o value ${FLASH_PART})
BOOTPART="UUID=${UUIDBOOT}"
}

write_device_files()
{
   cp ${PLTDIR}/${BOARDFAMILY}/boot/Image $ROOTFSMNT/boot
   cp ${PLTDIR}/${BOARDFAMILY}/boot/boot.ini $ROOTFSMNT/boot
   cp ${PLTDIR}/${BOARDFAMILY}/boot/env.txt $ROOTFSMNT/boot

   mkdir /mnt/volumio/rootfs/boot/dtb
   cp -R ${PLTDIR}/${BOARDFAMILY}/boot/dtb/* $ROOTFSMNT/boot/dtb
}

write_device_bootloader()
{
   dd if=${PLTDIR}/${BOARDFAMILY}/uboot/u-boot.VIM3L.sd.bin of=${LOOP_DEV} bs=444 count=1 conv=fsync
   dd if=${PLTDIR}/${BOARDFAMILY}/uboot/u-boot.VIM3L.sd.bin of=${LOOP_DEV} bs=512 skip=1 seek=1 conv=fsync 

}

copy_device_bootloader_files()
{
   mkdir /mnt/volumio/rootfs/boot/u-boot
   cp ${PLTDIR}/${BOARDFAMILY}/uboot/u-boot.VIM3L.sd.bin $ROOTFSMNT/boot/u-boot
}

write_boot_parameters()
{
   echo "
BOOTARGS_USER=loglevel=0 quiet splash bootdelay=1
bootpart=/dev/mmcblk1p1
imgpart=/dev/mmcblk1p2
datapart=/dev/mmcblk1p3
" > $ROOTFSMNT/boot/env.system.txt
}




