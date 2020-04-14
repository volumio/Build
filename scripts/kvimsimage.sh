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
mkfs -F -t ext4 -O ^metadata_csum,^64bit -L VIMAGE "${SYS_PART}" || mkfs -F -t ext4 -L VIMAGE "${SYS_PART}"
mkfs -F -t ext4 -O ^metadata_csum,^64bit -L VDATA "${DATA_PART}" || mkfs -F -t ext4 -L VDATA "${DATA_PART}"
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
	wget https://github.com/volumio/platform-khadas/raw/master/vims.tar.xz
	echo "Unpacking the platform files"
	tar xfJ vims.tar.xz
	rm vims.tar.xz
	cd ..
fi

echo "Use $MODEL u-boot naming as Krescue also needs it.."
case $MODEL in
  kvim1 )
  BOARD=VIM1
  ;;
  kvim2 )
  BOARD=VIM2
  ;;
  kvim3 )
  BOARD=VIM3
  ;;
  kvim3l )
  BOARD=VIM3L
  ;;
esac

echo "Installing u-boot u-boot.$BOARD.sd.bin"
dd if=platform-khadas/vims/uboot/u-boot.$BOARD.sd.bin of=${LOOP_DEV} bs=444 count=1 conv=fsync
dd if=platform-khadas/vims/uboot/u-boot.$BOARD.sd.bin of=${LOOP_DEV} bs=512 skip=1 seek=1 conv=fsync > /dev/null 2>&1

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
cp platform-khadas/vims/boot/env.system.txt /mnt/volumio/rootfs/boot
cp platform-khadas/vims/boot/env.txt /mnt/volumio/rootfs/boot
cp -r platform-khadas/vims/boot/dtb /mnt/volumio/rootfs/boot

echo "Keeping copies of u-boot files"
cp -r platform-khadas/vims/uboot /mnt/volumio/rootfs/boot
cp -r platform-khadas/vims/uboot-mainline /mnt/volumio/rootfs/boot

echo "Copying modules"
cp -Rp platform-khadas/vims/lib/modules /mnt/volumio/rootfs/lib/
echo "Copying general firmware"
cp -Rp platform-khadas/vims/lib/firmware /mnt/volumio/rootfs/lib/
echo "Adding services"
mkdir -p /mnt/volumio/rootfs/lib/systemd/system
cp platform-khadas/vims/lib/systemd/system/bluetooth-khadas.service /mnt/volumio/rootfs/lib/systemd/system
if [ ! "$MODEL" = kvim1 ];then
	cp platform-khadas/vims/lib/systemd/system/fan.service /mnt/volumio/rootfs/lib/systemd/system
fi	
echo "Adding usr/local/bin & usr/bin files"
cp -Rp platform-khadas/vims/usr/* /mnt/volumio/rootfs/usr

echo "Adding specific wlan firmware" 
cp -r platform-khadas/vims/hwpacks/wlan-firmware/brcm/ /mnt/volumio/rootfs/lib/firmware

echo "Copying rc.local"
cp platform-khadas/vims/etc/rc.local /mnt/volumio/rootfs/etc

echo "Adding Meson video firmware"
cp -r platform-khadas/vims/hwpacks/video-firmware/Amlogic/video /mnt/volumio/rootfs/lib/firmware/
cp -r platform-khadas/vims/hwpacks/video-firmware/Amlogic/meson /mnt/volumio/rootfs/lib/firmware/

echo "Adding Wifi & Bluetooth firmware and helpers"
cp platform-khadas/vims/hwpacks/bluez/hciattach-armhf /mnt/volumio/rootfs/usr/local/bin/hciattach
cp platform-khadas/vims/hwpacks/bluez/brcm_patchram_plus-armhf /mnt/volumio/rootfs/usr/local/bin/brcm_patchram_plus
if [ "$MODEL" = kvim3 ] || [ "$MODEL" = kvim3l ]; then
	echo "   fixing AP6359SA and AP6398S using the same chipid and rev for VIM3/VIM3L"
	mv /mnt/volumio/rootfs/lib/firmware/brcm/fw_bcm4359c0_ag_apsta_ap6398s.bin /mnt/volumio/rootfs/lib/firmware/brcm/fw_bcm4359c0_ag_apsta.bin
	mv /mnt/volumio/rootfs/lib/firmware/brcm/fw_bcm4359c0_ag_ap6398s.bin /mnt/volumio/rootfs/lib/firmware/brcm/fw_bcm4359c0_ag.bin
	mv /mnt/volumio/rootfs/lib/firmware/brcm/nvram_ap6398s.txt /mnt/volumio/rootfs/lib/firmware/brcm/nvram_ap6359sa.txt
	mv /mnt/volumio/rootfs/lib/firmware/brcm/BCM4359C0_ap6398s.hcd /mnt/volumio/rootfs/lib/firmware/brcm/BCM4359C0.hcd
#	cp platform-khadas/vims/var/lib/alsa/asound.state.vim3-3l /mnt/volumio/rootfs/var/lib/alsa/asound.state
#else
#	cp platform-khadas/vims/var/lib/alsa/asound.state.vim1-2 /mnt/volumio/rootfs/var/lib/alsa/asound.state
fi

echo "Preparing to run chroot for more Khadas ${MODEL} configuration"
cp scripts/kvimsconfig.sh /mnt/volumio/rootfs
cp scripts/install-kiosk.sh /mnt/volumio/rootfs
cp scripts/initramfs/init.nextarm /mnt/volumio/rootfs/root/init
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
MODEL=${MODEL}" > /mnt/volumio/rootfs/root/init.sh
chmod +x /mnt/volumio/rootfs/root/init.sh
sync


chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/kvimsconfig.sh
EOF

echo "Removing chroot files"
rm /mnt/volumio/rootfs/kvimsconfig.sh
rm /mnt/volumio/rootfs/root/init /mnt/volumio/rootfs/root/init.sh
rm /mnt/volumio/rootfs/usr/local/sbin/mkinitramfs-custom.sh

UIVARIANT_FILE=/mnt/volumio/rootfs/UIVARIANT	
if [ -f "${UIVARIANT_FILE}" ]; then	
    echo "Starting variant.js"	
    node variant.js	
    rm $UIVARIANT_FILE	
fi

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
