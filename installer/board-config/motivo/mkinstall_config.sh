#!/bin/bash

# Device Info
DEVICEBASE="motivo"
BOARDFAMILY=${PLAYER}
PLATFORMREPO="https://github.com/volumio/platform-motivo.git"
BUILD="armv7"
NONSTANDARD_REPO=no	# yes requires "non_standard_repo() function in make.sh 
LBLBOOT="BOOT"
LBLIMAGE="volumio"
LBLDATA="volumio_data"


# Partition Info
BOOT_TYPE=msdos			# msdos or gpt   
BOOT_START=21
BOOT_END=84
IMAGE_END=3500
BOOT=/mnt/boot
BOOTDELAY=
BOOTDEV="mmcblk0"
BOOTPART=/dev/mmcblk0p1

BOOTCONFIG=
TARGETBOOT="/dev/mmcblk2p1"
TARGETDEV="/dev/mmcblk2"
TARGETDATA="/dev/mmcblk2p3"
TARGETIMAGE="/dev/mmcblk2p2"
HWDEVICE="SOPine64-Motivo"
USEKMSG="yes"
UUIDFMT=
FACTORYCOPY="yes"


# Modules to load (as a blank separated string array)
MODULES="nls_cp437"

# Additional packages to install (as a blank separated string array)
#PACKAGES=""

# initramfs type
RAMDISK_TYPE=image			# image or gzip (ramdisk image = uInitrd, gzip compressed = volumio.initrd) 

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
   mkdir /mnt/volumio/rootfs/boot/dtb
   cp ${PLTDIR}/${BOARDFAMILY}/boot/Image $ROOTFSMNT/boot
   cp -R ${PLTDIR}/${BOARDFAMILY}/boot/dtb/* $ROOTFSMNT/boot/dtb
   cp ${PLTDIR}/${BOARDFAMILY}/usr/bin/i2crw1 $ROOTFSMNT/usr/bin/i2crw1
#  just to make sure it is executable
   chmod a+x $ROOTFSMNT/usr/bin/i2crw1

   echo "[info] Creating boot.scr image"
   cp ${PLTDIR}/${BOARDFAMILY}/boot/boot.cmd /$ROOTFSMNT/boot
   mkimage -C none -A arm -T script -d ${PLTDIR}/${BOARDFAMILY}/boot/boot.cmd $ROOTFSMNT/boot/boot.scr
}

write_device_bootloader()
{
   dd if=${PLTDIR}/${BOARDFAMILY}/u-boot/sunxi-spl.bin of=${LOOP_DEV} conv=fsync bs=8k seek=1
   dd if=${PLTDIR}/${BOARDFAMILY}/u-boot/u-boot.itb of=${LOOP_DEV} conv=fsync bs=8k seek=5
}

write_boot_parameters()
{
   echo "console=serial
panel_model=motivo
kernel_filename=Image
initrd_filename=uInitrd
fdtfile=allwinner/sun50i-a64-motivo-baseboard.dtb
bootpart-sd=rebootmode=normal 
hwdevice=hwdevice=SOPine64-Motivo
overlay_prefix=sun50i-a64
" > /mnt/volumio/rootfs/boot/uEnv.txt

}

copy_device_bootloader_files()
{
mkdir /mnt/volumio/rootfs/boot/u-boot
cp ${PLTDIR}/${BOARDFAMILY}/u-boot/sunxi-spl.bin $ROOTFSMNT/boot/u-boot
cp ${PLTDIR}/${BOARDFAMILY}/u-boot/u-boot.itb $ROOTFSMNT/boot/u-boot
}


