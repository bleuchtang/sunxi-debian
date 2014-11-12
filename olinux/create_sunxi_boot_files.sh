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

clone_or_pull (){
  repo=$1
  if [ -d /olinux/sunxi/$repo/ ] ; then 
    cd /olinux/sunxi/$repo/ && make clean && git pull 
  else
    git clone https://github.com/linux-sunxi/$repo /olinux/sunxi/$repo/
  fi
}

if [ -d /olinux/sunxi/u-boot/ ] ; then 
  cd /olinux/sunxi/u-boot/ && make clean && git pull 
else
  git clone git://git.denx.de/u-boot.git /olinux/sunxi/u-boot
fi

cd /olinux/sunxi/u-boot && make CROSS_COMPILE=arm-linux-gnueabihf A20-OLinuXino-Lime_config && make CROSS_COMPILE=arm-linux-gnueabihf-

# Sunxi kernel
clone_or_pull linux-sunxi
# Sunxi board configs
clone_or_pull sunxi-boards
# Sunxi tools 
clone_or_pull sunxi-tools

cp /olinux/a20_defconfig /olinux/sunxi/linux-sunxi/arch/arm/configs/.
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm a20_defconfig
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 uImage  
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 INSTALL_MOD_PATH=out modules
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 INSTALL_MOD_PATH=out modules_install

cd /olinux/sunxi/sunxi-tools/ && make
cd /olinux/sunxi/ && rm -f script.bin && ./sunxi-tools/fex2bin sunxi-boards/sys_config/a20/a20-olinuxino_lime2.fex script.bin
cd /olinux/sunxi/ && chmod +x script.bin 
