### Buildscripts for Volumio System

Copyright Michelangelo Guarise - 2016

#### Requirements

On a Debian (buster) host, the following packages are required:
```
build-essential
ca-certificates
curl
debootstrap
dosfstools
git
jq
kpartx
libssl-dev
lz4
lzop
md5deep
multistrap
parted
patch
pv
qemu-user-static
qemu-utils
qemu
squashfs-tools
sudo
u-boot-tools
wget
xz-utils
zip
```

#### How to

- Ensure you have installed all dependencies listed above.
- Clone the build repo, and launch the build script (requires root permissions).
  
```
git clone https://github.com/volumio/Build build
cd ./build
./build.sh -b <architecture> -d <device> -v <version>
```

where flags are :

 * -b `<arch>` Build a base rootfs with Multistrap.

   Options for the target architecture are:<br>
       **arm** (Raspbian armhf 32bit), **armv7** (Debian armhf 32bit), **armv8** (Debian arm64 64bit) <br>
       **x86** (Debian i386 32bit) or **x64** (Debian amd64 64bit).
 * -d `<dev>`  Create Image for Specific Devices.

   Example supported device names:<br>
       **mp1**, **nanopineo2**, **odroidn2**, **orangepilite**, **pi**, **rockpis**, **tinkerboard**, **x86_amd64**, **x86_i386**

   Run ```./build.sh -h``` for a definitive list; new devices are being added as time allows.
 * -v `<vers>` Version

Example: Build a Raspberry PI image from scratch, version 2.0 :
```
./build.sh -b arm -d pi -v 2.0
```

You do not have to build the base and the image at the same time.

Example: Build the base for x86 first and the image version `2.123` in a second step:

```
./build.sh -b x86
./build.sh -d x86_i386 -v 2.123
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


#### Caching packages

If you are doing a lot of volumio builds you may wish to save some bandwidth
by installing a package cache program, such as ```apt-cacher-ng```.
For a Debian-based system, these are the steps:

 * install, and configure so https package sources are not cached
   ```
   # apt-get install apt-cacher-ng
   # cat >> /etc/apt-cacher-ng/local.conf
   # do not cache https package sources
   PassThroughPattern: ^(.*):443$
   ^D
   # systemctl restart apt-cacher-ng
   ```
 * Set this environment variable; ```build.sh``` will do the rest.
   ```
   $ export APT_CACHE='http://localhost:3142'    # or similar
   $ sudo -E ./build.sh -b arm -d pi             # -E preserves the environment
   ```
 * To confirm operation, watch the log file during a build
   ```
   # tail -f /var/log/apt-cacher-ng/apt-cacher-ng.log
   ```

Some packages cannot easily be cached, because they are downloaded over https
(the cache is detected by the SSL certificate checks made by the https protocol).
Also some packages are downloaded via ```wget``` or similar, which do not make
use of the cache.
