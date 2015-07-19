cmd_firmware/keyspan/usa19.fw.gen.o := arm-linux-gnueabihf-gcc -Wp,-MD,firmware/keyspan/.usa19.fw.gen.o.d  -nostdinc -isystem /opt/toolchains/gcc-linaro-4.9-2014.11-x86_64_arm-linux-gnueabihf/bin/../lib/gcc/arm-linux-gnueabihf/4.9.3/include -I/media/nas/Volumio/Odroid-C/Odroid-C1/linux/arch/arm/include -Iarch/arm/include/generated  -Iinclude -I/media/nas/Volumio/Odroid-C/Odroid-C1/linux/arch/arm/include/uapi -Iarch/arm/include/generated/uapi -I/media/nas/Volumio/Odroid-C/Odroid-C1/linux/include/uapi -Iinclude/generated/uapi -include /media/nas/Volumio/Odroid-C/Odroid-C1/linux/include/linux/kconfig.h -D__KERNEL__ -mlittle-endian -Iarch/arm/mach-meson8b/include -Iarch/arm/plat-meson/include  -D__ASSEMBLY__ -mabi=aapcs-linux -mno-thumb-interwork -funwind-tables -marm -D__LINUX_ARM_ARCH__=7 -march=armv7-a  -include asm/unified.h -msoft-float -gdwarf-2         -c -o firmware/keyspan/usa19.fw.gen.o firmware/keyspan/usa19.fw.gen.S

source_firmware/keyspan/usa19.fw.gen.o := firmware/keyspan/usa19.fw.gen.S

deps_firmware/keyspan/usa19.fw.gen.o := \
  /media/nas/Volumio/Odroid-C/Odroid-C1/linux/arch/arm/include/asm/unified.h \
    $(wildcard include/config/arm/asm/unified.h) \
    $(wildcard include/config/thumb2/kernel.h) \

firmware/keyspan/usa19.fw.gen.o: $(deps_firmware/keyspan/usa19.fw.gen.o)

$(deps_firmware/keyspan/usa19.fw.gen.o):
