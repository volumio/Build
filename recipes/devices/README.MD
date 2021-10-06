## Devices

An overview of the currently supported devices are below.
Do note that an inclusion of a device, doesn't necessarily mean it is tested with every new release.

Most devices rely on the community to test, debug and maintain :-)

| Device       | Base  | Arch  | `VOLUMIO_HARDWARE` | `VOLUMIO_DEVICENAME` | Kernel                                                     | Type | Status |
| ------------ | ----- | ----- | -------------------- | -------------------- | ---------------------------------------------------------- | ---- | ------ |
| cuboxp       | armv7 | armhf | cuboxp               | Cubox Pulse          | [4.14.y](https://github.com/gkkpch/platform-cubox.git)     | C    | P      |
| kvim1        | armv7 | armhf | kvim1                | Khadas VIM1          | [4.9.y](https://github.com/volumio/platform-khadas.git)    | C    | P      |
| kvim2        | armv7 | armhf | kvim2                | Khadas VIM2          | [4.9.y](https://github.com/volumio/platform-khadas.git)    | C    | P      |
| kvim3        | armv7 | armhf | kvim3                | Khadas VIM3          | [4.9.y](https://github.com/volumio/platform-khadas.git)    | C    | P      |
| motivo       | armv7 | armhf | motivo               | Volumio Motivo       | [5.7.y](https://github.com/volumio/platform-motivo.git)    | O    | T      |
| mp1          | armv7 | armhf | mp1                  | Volumio Rivo         | [4.9.y](https://github.com/volumio/platform-khadas.git)    | O    | T      |
| nanopineo2   | armv7 | arm64 | nanopineo2           | NanoPi Neo2          | [4.11.y](https://github.com/volumio/platform-nanopi)       | C, O | P      |
| nanopineo3   | armv7 | armhf | nanopineo3           | Nanopi Neo3          | [5.4.y](https://github.com/volumio/platform-nanopi.git)    | C, O | T      |
| odroidc1     | armv7 | armhf | odroidc1             | Odroid-C1            | [3.10.y](https://github.com/volumio/platform-odroid.git)   | C    | P      |
| odroidc2     | armv7 | armhf | odroidc2             | Odroid-C2            | [3.16.y](https://github.com/volumio/platform-odroid.git)   | C    | P      |
| odroidc4     | armv7 | armhf | odroidc4             | Odroid-C4            | [4.9.y](https://github.com/volumio/platform-odroid.git)    | C    | P      |
| odroidn2     | armv7 | armhf | odroidn2             | Odroid-N2            | [4.9.y](https://github.com/volumio/platform-odroid.git)    | C    | P      |
| odroidxu4    | armv7 | armhf | odroidxu4            | Odroid-XU4           | [4.9.y](https://github.com/volumio/platform-odroid.git)    | C    | P      |
| orangepilite | armv7 | armhf | orangepilite         | Orange Pi            | [5.4.y](https://github.com/volumio/platform-orangepi)      | C    | T      |
| pine64base   | armv7 | armhf | pine64               | Pine64               | [5.7.y](https://github.com/volumio/platform-pine64.git)    | C    | P      |
| pine64plus   | armv7 | armhf | pine64plus           | Pine64+              | [5.7.y](https://github.com/volumio/platform-pine64.git)    | C    | P      |
| pine64solts  | armv7 | armhf | pine64solts          | soPine64-Pine64LTS   | [5.7.y](https://github.com/volumio/platform-pine64.git)    | C    | P      |
| pi           | arm   | armhf | pi                   | Raspberry Pi         | [5.4.y](https://github.com/raspberrypi/linux)              | S    | T      |
| rockpis      | armv7 | armhf | rockpis              | ROCK Pi S            | [5.6.y](https://github.com/ashthespy/platform-rockpis.git) | C    | P      |
| rock64       | armv7 | armhf | rock64               | ROCK64               | [4.4.y](https://github.com/volumio/platform-rock64.git)    | C    | P      |
| tinkerboard  | armv7 | armhf | tinkerboard          | Asus Tinkerboard     | [4.4.y](https://github.com/volumio/platform-asus.git)      | S    | P      |
| vszero       | armv7 | armhf | vszero               | Voltastream Zero     | [4.1.y](https://github.com/volumio/platform-pv.git)        | C    | P      |
| x86_amd64    | x64   | amd64 | x86_amd64            | x86_64               | [5.10.y](http://github.com/volumio/platform-x86)           | S    | T      |
| x86_i386     | x86   | i386  | x86_i386             | x86                  | [5.10.y](http://github.com/volumio/platform-x86)           | S    | T      |


#### Device Support Type `[C|S|O]`

C = Community porting<br>
S = Officially Supported device<br>
O = OEM or Volumio internal use<br>

#### Device Status `[P|T|M]`

P = Planned<br>
T = Testing<br>
M = Maintained<br>


