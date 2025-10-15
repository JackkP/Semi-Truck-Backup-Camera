how to build bootable SD card for Allwinner V3s:

# important to do this on an x86-64 machine since the cross-compiler will not be happy otherwise
# start by making a directory to build everything in
mkdir /home/user/lichee-pi-zero/mainline/
cd /home/user/lichee-pi-zero/mainline/

#################################################################################################
# build U-boot using modern cross-compiler and mainline u-boot

sudo apt-get update
sudo apt-get install crossbuild-essential-armhf

git clone https://github.com/u-boot/u-boot.git
cd u-boot

sudo apt-get install libncurses-dev libssl-dev libgnutls28-dev python3 python3-pyelftools

make LicheePi_Zero_defconfig
# edit the config if necessesary
sudo make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig
# set Boot options -> Autoboot options -> delay in seconds(...) to 0

make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

# return to parent directory
cd ..

#################################################################################################
# building Linux Kernel using mainline Linux

# clone the latest Linux
#git clone git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git --depth=1
# should also work with
git clone https://github.com/torvalds/linux.git --depth=1
cd linux

# build the .config file
sudo make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- sunxi_defconfig

# edit the .config file (if necessesary). There are like a million config settings (rip)
#sudo make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig

# Compile the kernel
# make zImage
sudo ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j$(nproc) zImage
# make device tree
sudo ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j$(nproc) dtbs
# make modules
sudo ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- make -j$(nproc) modules
sudo ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=./modules_install_out make modules modules_install
# make headers
sudo ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_HDR_PATH=./headers_install_out make headers_install

# return to parent directory
cd ..

#################################################################################################
# build rootfs using busybox (less practical, requires cross compiling a lot of packages manually)

# make rootfs folders
mkdir -p /home/user/lichee-pi-zero/mainline/busybox/rootfs/{bin,sbin,etc,proc,sys,usr/bin,usr/sbin,dev}
cd busybox

# clone busybox
git clone git://busybox.net/busybox.git
cd busybox

# setup config
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- defconfig
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig
# check Settings -> Build Options -> [*] Build static binary (no shared libs)
# uncheck Networking Utilities -> [ ] tc

# build and install into rootfs directory
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j$(nproc)
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- CONFIG_PREFIX=/home/user/lichee-pi-zero/mainline/busybox/rootfs install

# create an init script
sudo echo -e '#!/bin/sh\nmount -t proc none /proc\nmount -t sysfs none /sys\nexec /bin/sh' | sudo tee /home/user/lichee-pi-zero/mainline/busybox/rootfs/init
sudo chmod +x /home/user/lichee-pi-zero/mainline/busybox/rootfs/init

# create console and null inodes
sudo mknod -m 622 /home/user/lichee-pi-zero/mainline/busybox/rootfs/dev/console c 5 1
sudo mknod -m 666 /home/user/lichee-pi-zero/mainline/busybox/rootfs/dev/null c 1 3

# create init script:
sudo mkdir -p busybox/rootfs/etc/init.d
sudo vim busybox/rootfs/etc/init.d/rcS
###### that contains the following lines { ######
#!/bin/sh
# /etc/init.d/rcS - Minimal startup script

# Mount basic filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t tmpfs tmpfs /tmp

# Bring up loopback interface (optional)
ifconfig lo up

# Launch a shell on the console
/bin/sh
##### } ######
sudo chmod +x busybox/rootfs/etc/init.d/rcS

# return to build directory
cd ../..

#################################################################################################
# build rootfs using buildroot (saves effort compiling packages manually)

mkdir buildroot
cd buildroot

git clone https://gitlab.com/buildroot.org/buildroot.git
cd buildroot
make menuconfig

# -> Target options -> Target Architecture -> ARM
# -> Target options -> Target Architecture Variant -> ARM
# -> Target options -> Target ABI -> EABIhf
#
# -> Toolchain -> Toolchain type -> Buildroot toolchain
#
# -> System configuration -> Init system -> BusyBox
# -> System configuration -> Root password -> toortoor
#
# -> Target packages -> Networking applications -> wpa_supplicant
# -> Target packages -> Networking applications -> iw
# -> Target packages -> Networking applications -> wireless tools 
# doesn't work # -> Target packages -> Networking applications -> udhcpc???
# doesn't work #-> Target packages -> Hardware handling -> usbutils???
# 
# -> Filesystem images -> tar the root filesystem

make

cd ..

#################################################################################################

# create a boot script
sudo vim boot.cmd
# add the following lines:
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait panic=10
fatload mmc 0:1 0x42000000 zImage
fatload mmc 0:1 0x41800000 sun8i-v3s-licheepi-zero.dtb
bootz 0x42000000 - 0x41800000
# compile boot script
mkimage -C none -A arm -T script -d boot.cmd boot.scr


#################################################################################################
# write U-boot and Linux kernel image to a bootable SD card

# identify SD card:
lsblk

# assuming the card is connected via USB:
export card=/dev/sda # replace sda with the card
export p=""

# erase the card
sudo dd if=/dev/zero of=${card} bs=1M count=1

# write the bootloader to the SD card:
sudo dd if=u-boot/u-boot-sunxi-with-spl.bin of=${card} bs=1024 seek=8

# Partition the card with a 16MB boot partition starting at 1MB, and the rest as root partition
sudo blockdev --rereadpt ${card}
sudo cat <<EOT | sudo sfdisk ${card}
1M,16M,c
,,L
EOT

# Create the actual filesystems:
sudo mkfs.vfat ${card}${p}1
sudo mkfs.ext4 ${card}${p}2
sudo cardroot=${card}${p}2

# write the kernel image, dts, and boot script to the boot partition
sudo mount ${card}${p}1 /mnt/
sudo cp linux/arch/arm/boot/zImage /mnt/
sudo cp linux/arch/arm/boot/dts/allwinner/sun8i-v3s-licheepi-zero.dtb /mnt

# copy boot script to fat partition
sudo cp boot.scr /mnt

# copy rootfs to root partition on sd card
sudo mount ${card}${p}2 /mnt/

# busybox rootfs
# sudo cp -a busybox/rootfs/* /mnt

# buildroot rootfs
sudo tar -C /mnt/ -xvpf buildroot/buildroot/output/images/rootfs.tar

# check device nodes
sudo mknod -m 622 /mnt/dev/console c 5 1
sudo mknod -m 666 /mnt/dev/null c 1 3

# copy modules to rootfs
sudo mkdir -p /mnt/lib/modules
sudo rm -rf /mnt/lib/modules/
sudo cp -r linux/modules_install_out/lib /mnt/

sudo umount /mnt/




