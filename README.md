Build

Buildscripts for Volumio System

required :
squashfs-tools kpartx multistrap qemu-user-static samba debootstrap

- clone the build repo on your local folder  : git clone https://github.com/volumio/Build build
- cd to /build and type
./build.sh -b -d all -v 2.0 where switches are :
-b      --Build system with Multistrap, use arm or x86 to select architecture
-d      --Create Image for Specific Devices. Usage: all (all), pi, udoo, cuboxi, bbb, cubietruck, compulab
-l      --Create docker layer. Docker Repository name as as argument
-v      --Version
Example: Build a Raspberry PI image from scratch, version 2.0 : ./build.sh -b arm -d pi -v 2.0 -l reponame 
