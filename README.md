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
             **pi**, **odroidc1/2/xu4/x2**, **udooneo**, **udooqdl**, **cuboxi**, **pine64**, **sparky**, **bbb**, ***bpipro***, bpim2u, cubietruck, compulab, **x86**
 * -l `<repo>` Create docker layer. Give a Docker Repository name as the argument.
 * -v `<vers>` Version

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

#### Sources 

Kernel Sources

* [Raspberry PI](https://github.com/volumio/raspberrypi-linux)
* [X86](https://github.com/volumio/linux)
* [Odroid C1, branch odroidc-3.10.y](https://github.com/hardkernel/linux.git)
* [Odroid C2, branch odroidc2-3.14.y](https://github.com/hardkernel/linux.git)
* [Odroid X2](https://github.com/volumio/linux-odroid-public)
* [Odroid XU4](https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.4.tar.xz)
* [BeagleBoneBlack](https://github.com/volumio/linux-beagleboard-botic)

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
