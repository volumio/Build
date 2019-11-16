#!/bin/sh

# Default build for Debian 32bit
ARCH="armv7"

while getopts ":v:p:a:m:" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
    p)
      PATCH=$OPTARG
      ;;
    a)
      ARCH=$OPTARG
      ;;
	m)
	  MODEL=$OPTARG
	  ;;
  esac
done

BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-${MODEL}.img"

if [ "$ARCH" = arm ]; then
  DISTRO="Raspbian"
else
  DISTRO="Debian 32bit"
fi

echo "Creating Image File ${IMG_FILE} with ${DISTRO} rootfs"
dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800

echo "Creating Image Bed"
LOOP_DEV=`sudo losetup -f --show ${IMG_FILE}`
# Note: leave the first 20Mb free for the firmware
parted -s "${LOOP_DEV}" mklabel msdos
parted -s "${LOOP_DEV}" mkpart primary fat32 16MB 80MB
parted -s "${LOOP_DEV}" mkpart primary ext3 81MB 2581
parted -s "${LOOP_DEV}" mkpart primary ext3 2582 100%
parted -s "${LOOP_DEV}" set 1 boot on
parted -s "${LOOP_DEV}" print
partprobe "${LOOP_DEV}"
kpartx -s -a "${LOOP_DEV}"

BOOT_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
SYS_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
DATA_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p3`
echo "Using: " ${BOOT_PART}
echo "Using: " ${SYS_PART}
echo "Using: " ${DATA_PART}
if [ ! -b "${BOOT_PART}" ]
then
	echo "${BOOT_PART} doesn't exist"
	exit 1
fi

echo "Creating boot and rootfs filesystems"
mkfs -t vfat -n VBOOT "${BOOT_PART}"
mkfs -F -t ext4 -L VIMAGE "${SYS_PART}"
mkfs -F -t ext4 -L VSTORAGE "${DATA_PART}"
sync

echo "Preparing for the vims kernel/ platform files"
if [ -d platform-khadas ]
then
# if you really want to re-clone from the repo, then delete the platform-khadas folder
    # that will refresh all, see below
	cd platform-khadas
	if [ -f vims.tar.xz ]; then
	   echo "Found a new tarball, unpacking..."
	   [ -d vims ] || rm -r vims	
	   tar xfJ vims.tar.xz
	   rm vims.tar.xz 
	fi
	cd ..
else
	echo "Clone vims files from repo"
	mkdir platform-khadas
    cd platform-khadas
	wget https://github.com/gkkpch/platform-khadas/raw/master/vims.tar.xz
	echo "Unpacking the platform files"
	tar xfJ vims.tar.xz
	rm vims.tar.xz
	cd ..
fi

echo "Installing u-boot"
if [ "$MODEL" = kvim1 ]; then
	echo "   for khadas vim1..."
	dd if=platform-khadas/vims/uboot/u-boot.vim1.sd.bin of=${LOOP_DEV} bs=444 count=1 conv=fsync
	dd if=platform-khadas/vims/uboot/u-boot.vim1.sd.bin of=${LOOP_DEV} bs=512 skip=1 seek=1 conv=fsync > /dev/null 2>&1
else
	echo "   for khadas vim3l..."
	dd if=platform-khadas/vims/uboot/u-boot.vim3l.sd.bin of=${LOOP_DEV} bs=444 count=1 conv=fsync
	dd if=platform-khadas/vims/uboot/u-boot.vim3l.sd.bin of=${LOOP_DEV} bs=512 skip=1 seek=1 conv=fsync > /dev/null 2>&1
fi

echo "Preparing for Volumio rootfs"
if [ -d /mnt ]
then
	echo "/mount folder exist"
else
	mkdir /mnt
fi
if [ -d /mnt/volumio ]
then
	echo "Volumio Temp Directory Exists - Cleaning it"
	rm -rf /mnt/volumio/*
else
	echo "Creating Volumio Temp Directory"
	mkdir /mnt/volumio
fi

echo "Creating mount point for the images partition"
mkdir /mnt/volumio/images
mount -t ext4 "${SYS_PART}" /mnt/volumio/images
mkdir /mnt/volumio/rootfs
echo "Creating mount point for the boot partition"
mkdir /mnt/volumio/rootfs/boot
mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot

echo "Copying Volumio RootFs"
cp -pdR build/$ARCH/root/* /mnt/volumio/rootfs
echo "Copying boot files"
cp platform-khadas/vims/boot/Image /mnt/volumio/rootfs/boot
cp platform-khadas/vims/boot/config* /mnt/volumio/rootfs/boot
cp platform-khadas/vims/boot/boot.ini /mnt/volumio/rootfs/boot
cp -r platform-khadas/vims/boot/dtb /mnt/volumio/rootfs/boot
echo "Keeping copies of u-boot files"
cp -r platform-khadas/vims/uboot /mnt/volumio/rootfs/boot

echo "Copying modules"
cp -Rp platform-khadas/vims/lib/modules /mnt/volumio/rootfs/lib/
echo "Copying general firmware"
cp -Rp platform-khadas/vims/lib/firmware /mnt/volumio/rootfs/lib/
echo "Adding services"
cp -Rp platform-khadas/vims/lib/systemd/ /mnt/volumio/rootfs/lib
echo "Adding usr/local/bin & usr/bin files"
cp -Rp platform-khadas/vims/usr/* /mnt/volumio/rootfs/usr

echo "Adding emmc utility scripts"
cp platform-khadas/vims/opt/mmc_boots /mnt/volumio/rootfs/usr/bin
cp platform-khadas/vims/opt/mmcdisk /mnt/volumio/rootfs/usr/bin
cp platform-khadas/vims/opt/mmc_install_from_sd /mnt/volumio/rootfs/usr/bin
chmod +x /mnt/volumio/rootfs/usr/bin/mmc_boots
chmod +x /mnt/volumio/rootfs/usr/bin/mmcdisk 
chmod +x /mnt/volumio/rootfs/usr/bin/mmc_install_from_sd 

echo "Adding specific wlan firmware" 
cp -r platform-khadas/vims/hwpacks/wlan-firmware/brcm/ /mnt/volumio/rootfs/lib/firmware

echo "Adding Meson video firmware"
cp -r platform-khadas/vims/hwpacks/video-firmware/Amlogic/video /mnt/volumio/rootfs/lib/firmware/
cp -r platform-khadas/vims/hwpacks/video-firmware/Amlogic/meson /mnt/volumio/rootfs/lib/firmware/

#TODO: remove when volumio has been updated
echo "Adding vim-specific cards.json"
cp -r platform-khadas/vims/volumio/app/ /mnt/volumio/rootfs/volumio

echo "Preparing to run chroot for more Khadas ${MODEL} configuration"
cp scripts/kvim1config.sh /mnt/volumio/rootfs
#TODO: change init script
cp scripts/initramfs/init.nextarm_tvbox /mnt/volumio/rootfs/root/init
cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin

#copy the scripts for updating from usb
wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs
echo $PATCH > /mnt/volumio/rootfs/patch

if [ -f "/mnt/volumio/rootfs/$PATCH/patch.sh" ] && [ -f "config.js" ]; then
        if [ -f "UIVARIANT" ] && [ -f "variant.js" ]; then
                UIVARIANT=$(cat "UIVARIANT")
                echo "Configuring variant $UIVARIANT"
                echo "Starting config.js for variant $UIVARIANT"
                node config.js $PATCH $UIVARIANT
                echo $UIVARIANT > /mnt/volumio/rootfs/UIVARIANT
        else
                echo "Starting config.js"
                node config.js $PATCH
        fi
fi

echo "UUID_DATA=$(blkid -s UUID -o value ${DATA_PART})
UUID_IMG=$(blkid -s UUID -o value ${SYS_PART})
UUID_BOOT=$(blkid -s UUID -o value ${BOOT_PART})
" > /mnt/volumio/rootfs/root/init.sh
chmod +x /mnt/volumio/rootfs/root/init.sh
sync


chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/kvim1config.sh
EOF

echo "Removing chroot files"
rm /mnt/volumio/rootfs/kvim1config.sh
rm /mnt/volumio/rootfs/root/init /mnt/volumio/rootfs/root/init.sh
rm /mnt/volumio/rootfs/usr/local/sbin/mkinitramfs-custom.sh

echo "Unmounting chroot temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys
sync

echo "Finalizing Rootfs creation"
sh scripts/finalize.sh

echo "Preparing rootfs base for SquashFS"

if [ -d /mnt/squash ]; then
	echo "Volumio SquashFS Temp Dir Exists - Cleaning it"
	rm -rf /mnt/squash/*
else
	echo "Creating Volumio SquashFS Temp Dir"
	mkdir /mnt/squash
fi

echo "Copying Volumio rootfs to Temp Dir"
cp -rp /mnt/volumio/rootfs/* /mnt/squash/

if [ -e /mnt/kernel_current.tar ]; then
	echo "Volumio Kernel Partition Archive exists - Cleaning it"
	rm -rf /mnt/kernel_current.tar
fi

echo "Creating Kernel Partition Archive"
tar cf /mnt/kernel_current.tar --exclude='resize-volumio-datapart' -C /mnt/squash/boot/ .

echo "Removing the Kernel"
rm -rf /mnt/squash/boot/*

echo "Creating SquashFS, removing any previous one"
rm -r Volumio.sqsh
mksquashfs /mnt/squash/* Volumio.sqsh

echo "Squash filesystem created"
echo "Cleaning squash environment"
rm -rf /mnt/squash

#copy the squash image inside the boot partition
cp Volumio.sqsh /mnt/volumio/images/volumio_current.sqsh
sync

echo "==> Khadas ${MODEL} device installed"
echo "Unmounting temp devices"
umount -l /mnt/volumio/images
umount -l /mnt/volumio/rootfs/boot

echo "Releasing loop devices"
dmsetup remove_all
losetup -d ${LOOP_DEV}
sync

md5sum "$IMG_FILE" > "${IMG_FILE}.md5"
