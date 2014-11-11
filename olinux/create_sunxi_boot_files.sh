#/bin/sh

######################
#     Sunxi part     #
######################

# Sunxi u-boot
#if [ -d /olinux/sunxi/u-boot-sunxi/ ] ; then 
#  cd /olinux/sunxi/u-boot-sunxi/ && make clean && git pull 
#else
#  git clone -b sunxi https://github.com/linux-sunxi/u-boot-sunxi.git /olinux/sunxi/u-boot-sunxi
#fi
#
#cd /olinux/sunxi/u-boot-sunxi && make CROSS_COMPILE=arm-linux-gnueabihf A20-OLinuXino-Lime_config && make CROSS_COMPILE=arm-linux-gnueabihf-

if [ -d /olinux/sunxi/u-boot/ ] ; then 
  cd /olinux/sunxi/u-boot/ && make clean && git pull 
else
  git clone git://git.denx.de/u-boot.git 
fi

cd /olinux/sunxi/u-boot && make CROSS_COMPILE=arm-linux-gnueabihf A20-OLinuXino-Lime_config && make CROSS_COMPILE=arm-linux-gnueabihf-

# Sunxi kernel
if [ -d /olinux/sunxi/linux-sunxi/ ] ; then 
  cd /olinux/sunxi/linux-sunxi/ && make clean && git pull 
else
  git clone https://github.com/linux-sunxi/linux-sunxi -b stage/sunxi-3.4 /olinux/sunxi/linux-sunxi
fi

cp /olinux/a20_defconfig /olinux/sunxi/linux-sunxi/arch/arm/configs/.
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm a20_defconfig
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 uImage  
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 INSTALL_MOD_PATH=out modules
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 INSTALL_MOD_PATH=out modules_install

# Sunxi fex2bin
if [ -d /olinux/sunxi/sunxi-tools/ ] ; then 
  cd /olinux/sunxi/sunxi-tools/ && make clean && git pull 
else
 git clone https://github.com/linux-sunxi/sunxi-tools /olinux/sunxi/sunxi-tools 
fi

cd /olinux/sunxi/sunxi-tools/ && make
cd /olinux/sunxi/ && ./sunxi-tools/fex2bin ../script.fex script.bin 
cd /olinux/sunxi/ && chmod +x script.bin 
