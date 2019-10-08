### Buildscripts for Volumio System

Copyright Michelangelo Guarise - 2016

#### Requirements

```
git squashfs-tools kpartx multistrap qemu-user-static samba debootstrap parted dosfstools qemu binfmt-support qemu-utils
```

#### How to

- clone the build repo on your local folder  : git clone https://github.com/volumio/Build build
- if on Ubuntu, you may need to remove `$forceyes` from line 989 of /usr/sbin/multistrap
- cd to /build and type

```
./build.sh -b <architecture> -d <device> -v <version>
```

where switches are :

 * -b `<arch>` Build a full system image with Multistrap. 
 Options for the target architecture are **arm** (Raspbian), **armv7** (Debian 32bit), **armv8** (Debian 64bit) or **x86** (Debian 32bit).
 * -d `<dev>`  Create Image for Specific Devices. Supported device names:
             **pi**, **odroidc1/2/xu4/x2**, **udooneo**, **udooqdl**, **cuboxi**, **pine64**, **sparky**, **bbb**, **bpipro**, bpim2u, cubietruck, compulab, **x86**
 * -l `<repo>` Create docker layer. Give a Docker Repository name as the argument.
 * -v `<vers>` Version
 * -s `<buster>` Allows building for Debian suite 'buster'. Omit this option when building for Debian jessie

Example: Build a Raspberry PI image from scratch, version 2.0 : 
```
./build.sh -b arm -d pi -v 2.0 -l reponame 
```

You do not have to build the architecture and the image at the same time. 

Example: Build the architecture for x86 first and the image version MyVersion in a second step:
```
./build.sh -b x86

./build.sh -d x86 -v MyVersion
```

#### Updates for Debian Buster
See the list at the end of this README

#### Modifications for Building on a Ubuntu or Debian Buster host

This regards **multistrap** (used for building the rootfs) and the use of  **mkinitramfs-custom.sh** (jessie) or **mkinitramfs-volumio.sh** (buster).

**Multistrap**
This does not work OOTB in Debian Buster and Ubuntu, please patch 

##### Ubuntu
Add the following 3 lines to the **build.sh** script, just before calling the multistrap script (code as follows):

	..
	..
	mkdir -p "build/$BUILD/root/etc/apt/trusted.gpg.d"
	apt-key --keyring "build/$BUILD/root/etc/apt/trusted.gpg.d/debian.gpg"  adv --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-key 7638D0442B90D010
	apt-key --keyring "build/$BUILD/root/etc/apt/trusted.gpg.d/debian.gpg"  adv --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-key CBF8D6FD518E17E1
	multistrap -a "$ARCH" -f "$CONF"
	..
	..

##### Debian Buster
The above does not work for Debian, but instead patch "/usr/sbin/multistrap".
Look for the line with "AllowInsecureRepositories=true"" and add an extra line above it to allow unauthenticated packages, it should read like this:

	..
	..
	$config_str .= " -o Apt::Get::AllowUnauthenticated=true;"
	$config_str .= " -o Acquire::AllowInsecureRepositories=true";
	..
	..
	 
**mkinitramfs.sh**
This script is known to fail on Ubuntu and Debian Buster, trying to locate the rootfs device.
This only happens with <device>config.sh scripts which change the initramfs config from MODULES=most to **MODULES=dep**.
As Modules=dep does not seem to add relevant additional module anyway, replace the usage of MODULES=dep to **MODULES=list**, which will only add the modules as specified in the list. The standard dependencies get added anyway. Tested with a number of these scripts, they all work.

#### Sources 

Kernel Sources

* [Raspberry PI](https://github.com/volumio/raspberrypi-linux)
* [X86](https://github.com/volumio/linux)
* [Odroid C1, branch odroidc-3.10.y](https://github.com/hardkernel/linux.git)
* [Odroid C2, branch odroidc2-3.14.y](https://github.com/hardkernel/linux.git)
* [Odroid X2](https://github.com/volumio/linux-odroid-public)
* [Odroid XU4](https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.tar.xz)
* [BeagleBoneBlack](https://github.com/volumio/linux-beagleboard-botic)
* [armbian](https://github.com/igorpecovnik)

Main Packages Sources

* [MPD](https://github.com/volumio/MPD) by Max Kellerman
* [Shairport-Sync](https://github.com/volumio/shairport-sync) by Mike Brady
* [Node.JS](https://github.com/volumio/node) by Ryan Dahl
* [SnapCast](https://github.com/volumio/snapcast) by Badaix 
* [Upmpdcli](https://github.com/volumio/upmpdcli) by Justin Maggard

Debian Packages Sources (x86)

All Debian-retrieved packages sources can be found at the [debian-sources Repository](https://github.com/volumio/debian-sources)

Raspbian Packages Sources (armhf)

All Raspbian-retrieved packages sources can be found at the [raspbian-sources Repository](https://github.com/volumio/raspbian-sources)

If any information, source package or license is missing, please report it to info at volumio dot org  

### armbian-based images

In case of lacking native support in volumio there is the option to build
images based on Armbian ( www.armbian.com ) which supports a variety of
PI clones - 

Example:

```
./build.sh -b arm -d armbian_bananapipro_vanilla -v 2.0
```

where

* armbian_ prefix is used to indicate the use of armbian
* boardtype in the notation of armbian
* _vanilla as postfix for mainline kernel or _legacy for android kernel

#### armbian kernels

please see notes in armbiam community which kernel is the best - or
if there are any restrictions that apply in your case
e.g. some mainline kernel still do not have stable ports of all devices, e.g. ethernet driver, while legacy kernel may miss other features.
In all cases even lecagy kernels come with overlayfs and squashfs support.

sucessfully tested images:

* armbian_bananapi_legacy
* armbian_bananapipro_legacy
* armbian_cubieboard2_legacy
* armbian_cubietruck_legacy
* armbian_bananapi_vanilla
* armbian_bananapipro_vanilla
* armbian_cubieboard2_vanilla
* armbian_cubietruck_vanilla

#### notes and known issues armbian

* current sunxi bootloader version 5.25/armbian is not working, solved by explicitely using 5.23 (be careful with apt-get upgrade later on)
* Partition 1 has been changed from vfat to ext4 because armbian scripts are
using symbolic links
* kernel, ramdisk and squashfs may be larger compared to native support images due to extra packages required by armbian build routines

* armbian_orangepipc_legacy ... not booting

others may work at once or with minor adaptions
*

### List of modifications for Debian Buster (currently only for X86)

#### build.sh
- add a new option (-s)  to allow building for other Debian suites.  
Currently only buster can be used, or omit the option to build for jessie (default)
- add a comment (as a warning) just before the call to multistrap, pointing to issues on Debian Buster and Ubuntu host platforms, referring to this README.md for further info.
- depending on OS version, either call the jessie or buster device image script  
Currently supported:  
x86**b**-image.sh (calls x86**b**-config.sh)

#### recipes
- added two new recipes: **x86-buster.conf** and **x86-dev-buster.conf**
- removed **base-files** and **base-passwd** from the recipes, they get added automatically

#### volumioconfig.sh
- fetch OS version
- the dash.preinst script was removed according to:
			https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=890073  
Action:  when OS version = buster, then skip "/var/lib/dpkg/info/dash.preinst install"
	
		if [ ! $OS_VERSION_ID = 10 ]; then
		  /var/lib/dpkg/info/dash.preinst install
		fi

- The configuration of package **base-files** depends on package **base-passwd**.  
However, base-files gets bootstrapped before base-passwd  
(This is not a result of removing them from the recipe, it has no influence)  
Solution: create a valid /etc/passwd before confioguring anything else.  
Use the pre install script for that, to be found in /var/lib/dpgg/info:

		if [ $OS_VERSION_ID = 10 ]; then
		  echo "Working around a debian buster package dependency issue"
		  /var/lib/dpkg/info/base-passwd.preinst install
		fi
- depending on OS version, skip Shairport-Sync
- depending on OS version, install volumio-specific packages

#### init-x86
- adding a function to update UUID's, avoiding code being repeated
- adding "datapart" option to /proc/cmdline
- modprobe modules for nvme and emmc support
- fixing a problem with moving the backup GPT table
- always resize the data partition when the disk is not fully used (not just on first boot)

#### x86image.sh

- building for buster  
updated/ additional packages (new kernel etc.)  
currently adding up-to-date firmware from a tarball  
todo: remove the use of the firmware tarball  
todo: add the relevant firmware packages during multistrap  

#### x86config.sh
- remove firmware package (.deb) install, unpack tarball instead (see x86image.sh)
- syslinux.tmpl  
add "net.ifnames=0 biosdevname=0" and "datapart=" to /proc/cmdline
- grub.tmpl and /etc/default/grub"  
add "net.ifnames=0 biosdevname=0" and "datapart=" to /proc/cmdline
- adding nvme, emmc modules to /etc/initramfs-tools/modules list

#### mkinitramfs-custom.sh
- the current "jessie" mkinitramfs-custom.sh version fails in hook-function ""zz-busybox".  
It appears to be incompatible with a buster build.  
Rewritten based on core code of the original mkinitramfs script from buster's initramfs-tools package.  
NOTE: the previous version used "cp" to copy volumio-specific binary packages, along with a copy of their library dependencies.  
With buster, this method is not waterproof and results in an unusable initramfs.  
Instead of "cp", the new version shall always use "copy_exec", which automatically adds the necessary dependencies.   

TODO: mkinitramfs-custom.sh is not suitable for multiple kernels yet.  
Therefore a PI won't work at the moment, this is WIP!!

#### End of Buster modifications
 

