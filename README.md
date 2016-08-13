Build

Buildscripts for Volumio System

required :
git squashfs-tools kpartx multistrap qemu-user-static samba debootstrap parted dosfstools qemu binfmt-support

required for building x86 : qemu-utils

- clone the build repo on your local folder  : git clone https://github.com/volumio/Build build
- if on Ubuntu, you may need to remove `$forceyes` from line 989 of /usr/sbin/multistrap
- cd to /build and type
```
./build.sh -b <architecture> -d <device> -v <version>
```
where switches are :

 * -b `<arch>` Build a full system image with Multistrap. Options for the target architecture are **arm** or **x86**.
 * -d `<dev>`  Create Image for Specific Devices. Supported device names:
             **pi**, **odroidc1/2/xu4/x2**, udoo, cuboxi, bbb, cubietruck, compulab, **x86**
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

