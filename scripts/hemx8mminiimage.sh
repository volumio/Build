#!/bin/sh

# Build Architecture Debian 32bit
ARCH="armv7"

while getopts ":v:p:a:" opt; do
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
  esac
done

BUILDDATE=$(date -I)
IMG_FILE="Volumio${VERSION}-${BUILDDATE}-hemx8mmini.img"

if [ "$ARCH" = arm ]; then
  DISTRO="Raspbian"
else
  DISTRO="Debian 32bit"
fi

echo "[INFO] Creating Image File ${IMG_FILE} with ${DISTRO} rootfs"

dd if=/dev/zero of=${IMG_FILE} bs=1M count=2800

echo "[INFO] Creating Image Bed"
LOOP_DEV=`losetup -f --show ${IMG_FILE}`
# Note: leave the first 20Mb free for the firmware
parted -s "${LOOP_DEV}" mklabel msdos
parted -s "${LOOP_DEV}" mkpart primary fat16 21 84
parted -s "${LOOP_DEV}" mkpart primary ext3 84 2500
parted -s "${LOOP_DEV}" mkpart primary ext3 2500 100%
parted -s "${LOOP_DEV}" set 1 boot on
parted -s "${LOOP_DEV}" print
partprobe "${LOOP_DEV}"
kpartx -s -a "${LOOP_DEV}"

BOOT_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
SYS_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p2`
DATA_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p3`

if [ ! -b "${BOOT_PART}" ]
then
	echo "[ERR] ${BOOT_PART} doesn't exist"
	exit 1
fi

echo "[INFO] Creating boot and rootfs filesystems"
mkfs -t vfat -n BOOT "${BOOT_PART}"
mkfs -F -t ext4 -O ^metadata_csum,^64bit -L volumio "${SYS_PART}" || mkfs -F -t ext4 -L volumio "${SYS_PART}"
mkfs -F -t ext4 -O ^metadata_csum,^64bit -L volumio_data "${DATA_PART}" || mkfs -F -t ext4 -L volumio_data "${DATA_PART}"
sync

echo "[INFO] Preparing for the hemx8mmini kernel/ platform files"
if [ -d platform-variscite ]
then
# if you really want to re-clone from the repo, then delete the platform-hemx8mmini folder
    # that will refresh all, see below
   cd platform-variscite
   if [ -f hemx8mmini.tar.xz ]; then
      echo "[INFO] Found a new tarball, unpacking..."
      [ -d hemx8mmini ] || rm -r hemx8mmini	
      tar xfJ hemx8mmini.tar.xz
      rm hemx8mmini.tar.xz 
   fi
   cd ..
else
   echo "[INFO] Get hemx8mmini files from repo"
   git clone https://github.com/volumio/platform-hem-var-som-mx8m-mini platform-variscite --depth 1
   cd platform-variscite
   tar xfJ hemx8mmini.tar.xz
   rm hemx8mmini.tar.xz
   cd ..
fi

echo "[INFO] Copying the hemx8mmini bootloader"
sudo dd if=platform-variscite/hemx8mmini/uboot/imx-boot-sd.bin of=${LOOP_DEV} bs=1K seek=33 conv=fsync

echo "[INFO] Preparing for Volumio rootfs"
if [ -d /mnt ]
then
	echo "[INFO] /mount folder exist"
else
	mkdir /mnt
fi
if [ -d /mnt/volumio ]
then
	echo "[INFO] Volumio Temp Directory Exists - Cleaning it"
	rm -rf /mnt/volumio/*
else
	echo "[INFO] Creating Volumio Temp Directory"
	mkdir /mnt/volumio
fi

echo "[INFO] Creating mount point for the images partition"
mkdir /mnt/volumio/images
mount -t ext4 "${SYS_PART}" /mnt/volumio/images
mkdir /mnt/volumio/rootfs
mkdir /mnt/volumio/rootfs/boot
mount -t vfat "${BOOT_PART}" /mnt/volumio/rootfs/boot

echo "[INFO] Copying Volumio RootFs"
cp -pdR build/$ARCH/root/* /mnt/volumio/rootfs

echo "[INFO] Copying hemx8mmini dtb and boot files"
cp platform-variscite/hemx8mmini/boot/* /mnt/volumio/rootfs/boot

echo "[INFO] Copying boot logo (to be customized)"
cp platform-variscite/hemx8mmini/variscite/splash.bmp /mnt/volumio/rootfs/boot

echo "[INFO] Compiling u-boot boot script"
mkimage -C none -A arm -T script -d platform-variscite/hemx8mmini/boot/boot.cmd /mnt/volumio/rootfs/boot/boot.scr

echo "[INFO] Copying kernel configuration file"
cp platform-variscite/hemx8mmini/boot/config* /mnt/volumio/rootfs/boot

echo "[INFO] Copying kernel modules & firmware"
cp -pdR platform-variscite/hemx8mmini/lib/modules /mnt/volumio/rootfs/lib/
cp -pdR platform-variscite/hemx8mmini/variscite/firmware/* /mnt/volumio/rootfs/lib/firmware

echo "[INFO] Copying ALSA defaults"
cp platform-variscite/hemx8mmini/variscite/asound.state /mnt/volumio/rootfs/usr/share/alsa/
cp platform-variscite/hemx8mmini/variscite/asound.conf /mnt/volumio/rootfs/etc

echo "[INFO] Copying BT service, scripts and configs"
mkdir /mnt/volumio/rootfs/etc/bluetooth
cp platform-variscite/hemx8mmini/variscite/brcm_patchram_plus /mnt/volumio/rootfs/usr/bin
chmod +x /mnt/volumio/rootfs/usr/bin/brcm_patchram_plus
cp platform-variscite/hemx8mmini/variscite/imx8mm-var-dart/main.conf /mnt/volumio/rootfs/etc/bluetooth
cp platform-variscite/hemx8mmini/variscite/imx8mm-var-dart/variscite-bt.conf /mnt/volumio/rootfs/etc/bluetooth
cp platform-variscite/hemx8mmini/variscite/variscite-bt /mnt/volumio/rootfs/etc/bluetooth
chmod +x /mnt/volumio/rootfs/etc/bluetooth/variscite-bt
cp platform-variscite/hemx8mmini/variscite/variscite-bt-common.sh /mnt/volumio/rootfs/etc/bluetooth
chmod +x /mnt/volumio/rootfs/etc/bluetooth/variscite-bt-common.sh
cp platform-variscite/hemx8mmini/variscite/variscite-bt.service /mnt/volumio/rootfs/lib/systemd/system

echo "[INFO] Install blacklist"
cp platform-variscite/hemx8mmini/variscite/imx8mm-var-dart/blacklist.conf /mnt/volumio/rootfs/etc/modprobe.d

echo "[INFO] Copying WiFi service, scripts and configs"
mkdir /mnt/volumio/rootfs/etc/wifi/
cp platform-variscite/hemx8mmini/variscite/imx8mm-var-dart/variscite-wifi.conf /mnt/volumio/rootfs/etc/wifi/
cp platform-variscite/hemx8mmini/variscite/imx8mm-var-dart/variscite-wifi-common.sh /mnt/volumio/rootfs/etc/wifi/
chmod +x /mnt/volumio/rootfs/etc/wifi/variscite-wifi-common.sh
cp platform-variscite/hemx8mmini/variscite/variscite-wifi /mnt/volumio/rootfs/etc/wifi/
chmod +x /mnt/volumio/rootfs/etc/wifi/variscite-wifi
cp platform-variscite/hemx8mmini/variscite/variscite-wifi.service /mnt/volumio/rootfs/lib/systemd/system

echo "[INFO] Copying rc.local (set min_free_kbytes)"
cp platform-variscite/hemx8mmini/variscite/rc.local /mnt/volumio/rootfs/etc

echo "[INFO] Copying the binary for updating from usb during initrd"
wget -P /mnt/volumio/rootfs/root http://repo.volumio.org/Volumio2/Binaries/volumio-init-updater

sync

echo "[INFO] Preparing to run chroot for more hemx8mmini configuration "
cp scripts/hemx8mminiconfig.sh /mnt/volumio/rootfs
cp scripts/initramfs/init.nextarm /mnt/volumio/rootfs/root/init
cp scripts/initramfs/mkinitramfs-custom.sh /mnt/volumio/rootfs/usr/local/sbin

mount /dev /mnt/volumio/rootfs/dev -o bind
mount /proc /mnt/volumio/rootfs/proc -t proc
mount /sys /mnt/volumio/rootfs/sys -t sysfs

echo $PATCH > /mnt/volumio/rootfs/patch

echo "UUID_DATA=$(blkid -s UUID -o value ${DATA_PART})
UUID_IMG=$(blkid -s UUID -o value ${SYS_PART})
UUID_BOOT=$(blkid -s UUID -o value ${BOOT_PART})
" > /mnt/volumio/rootfs/root/init.sh
chmod +x /mnt/volumio/rootfs/root/init.sh

if [ -f "/mnt/volumio/rootfs/$PATCH/patch.sh" ] && [ -f "config.js" ]; then
        if [ -f "UIVARIANT" ] && [ -f "variant.js" ]; then
                UIVARIANT=$(cat "UIVARIANT")
                echo "[INFO] Configuring variant $UIVARIANT"
                echo "[INFO] Starting config.js for variant $UIVARIANT"
                node config.js $PATCH $UIVARIANT
                echo $UIVARIANT > /mnt/volumio/ro
        else
                echo "[INFO] Starting config.js"
                node config.js $PATCH
        fi
fi

chroot /mnt/volumio/rootfs /bin/bash -x <<'EOF'
su -
/hemx8mminiconfig.sh
EOF

UIVARIANT_FILE=/mnt/volumio/rootfs/UIVARIANT
if [ -f "${UIVARIANT_FILE}" ]; then
    echo "[INFO] Starting variant.js"
    node variant.js
    rm $UIVARIANT_FILE
fi

#cleanup
rm /mnt/volumio/rootfs/root/init.sh /mnt/volumio/rootfs/hemx8mminiconfig.sh /mnt/volumio/rootfs/root/init

echo "[INFO] Unmounting Temp devices"
umount -l /mnt/volumio/rootfs/dev
umount -l /mnt/volumio/rootfs/proc
umount -l /mnt/volumio/rootfs/sys

echo "[INFO] ==> hemx8mmini device image installed"
sync

echo "[INFO] Finalizing Rootfs creation"
sh scripts/finalize.sh

echo "[INFO] Preparing rootfs base for SquashFS"

if [ -d /mnt/squash ]; then
	echo "[INFO] Volumio SquashFS Temp Dir Exists - Cleaning it"
	rm -rf /mnt/squash/*
else
	echo "[INFO] Creating Volumio SquashFS Temp Dir"
	mkdir /mnt/squash
fi

echo "[INFO] Copying Volumio rootfs to Temp Dir"
cp -rp /mnt/volumio/rootfs/* /mnt/squash/

if [ -e /mnt/kernel_current.tar ]; then
	echo "[INFO] Volumio Kernel Partition Archive exists - Cleaning it"
	rm -rf /mnt/kernel_current.tar
fi

echo "[INFO] Creating Kernel Partition Archive"
tar cf /mnt/kernel_current.tar --exclude='resize-volumio-datapart' -C /mnt/squash/boot/ .

echo "[INFO] Removing the Kernel"
rm -rf /mnt/squash/boot/*

echo "[INFO] Creating SquashFS, removing any previous one"
if [ -f Volumio.sqsh ]; then
  rm -r Volumio.sqsh
fi
OS_VERSION_TARGET=$(cat /mnt/squash/etc/os-release | grep ^VERSION_ID | tr -d 'VERSION_ID="')
OS_VERSION_HOST=$(cat /etc/os-release | grep ^VERSION_ID | tr -d 'VERSION_ID="')
if [ ! "${OS_VERSION_TARGET}" = "8" ] && [ ! "${OS_VERSION_HOST}" = "8" ]; then
	SQUASHFSOPTS="-comp zstd"
fi
mksquashfs /mnt/squash/* Volumio.sqsh $SQUASHFSOPTS

echo "[INFO] Squash filesystem created"
echo "[INFO] Cleaning squash environment"
rm -rf /mnt/squash

#copy the squash image inside the boot partition
cp Volumio.sqsh /mnt/volumio/images/volumio_current.sqsh
sync
echo "[INFO] Unmounting Temp Devices"
umount -l /mnt/volumio/images
umount -l /mnt/volumio/rootfs/boot

dmsetup remove_all
losetup -d ${LOOP_DEV}
sync
