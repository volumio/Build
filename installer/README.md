NOTE: The structure will likely need modification to fit in with the refactoring of the 
build process when this has been completed.

**Usage**

~~~
./mkinstaller.sh -i <location of the volumio image>
~~~

where currently supported devices are  **Volumio MP1** and **Volumio Motivo**


**Build Process**
It consists of 4 components:

*mkinstaller.sh*  
This is the main build script.
It creates an autoinstaller image with 
- a kernel
- an initramfs (incl. scripts and config)
- the tarbal with the contents of the volumio image's boot partition
- the volumiocurrent.sqsh
- the bootloader files (u-boot)

*mkinstaller_config.sh*  
Device-specific mkinstaller configuration and  script functions

*mkinitrd.sh*  
A build script running in chroot.  
It creates the runtime, board-specific initramfs, which acts as the "autoinstaller" 

**Runtime Process**  
The runtime autoinstaller is an image, which can be flashed to an SD card.  
The image will load nothing more than a kernel and an initramfs, it does not have a rootfs.  
The initramfs is board-specific and is made up of:   

*init_script*  
This is the main init script within the initramfs.
It mounts the boot partiton of the autoinstaller, loads the necessary modules, checks whether UUID are used and checks whether the target device has been brought up.
It clears all existing partitions, creates the boot and imgpart partitions according to the config, and the data partiton taking the rest of the disk device.
It mounts the 3 partitions and unpacks the boot partiton tarbal and copies the .sqsh file to the image partition. When UUIDs are used in the boot configuration, they will be replaced by the ones from the newly created partitions.

Process start and finish will be notified by the led functions (board-specific).   

*gen-functions*  
These are generic script functions, used by the init script.   
It is the same for each installer.
 
*board-functions*  
These are the board-specific function, used by the init scripts.
Example: write_device_bootloader, which is different for most boards.
