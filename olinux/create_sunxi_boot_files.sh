#/bin/sh

######################
#     Sunxi part     #
######################

offline=$1

clone_or_pull (){
  project=$1
  repo=$2
  if [ "$offline" ] ; then
    cd /olinux/sunxi/$project/ && make clean
    return 0
  fi 
  if [ -d /olinux/sunxi/$project/ ] ; then 
    cd /olinux/sunxi/$project/ && make clean && git pull 
  else
    git clone $repo/$project /olinux/sunxi/$project/
  fi
}

# Sunxi u-boot
#clone_or_pull u-boot-sunxi
clone_or_pull u-boot.git git://git.denx.de
cd /olinux/sunxi/u-boot.git && make CROSS_COMPILE=arm-linux-gnueabihf A20-OLinuXino-Lime_config && make CROSS_COMPILE=arm-linux-gnueabihf-

# Sunxi kernel
clone_or_pull linux-sunxi https://github.com/linux-sunxi
cp /olinux/a20_defconfig /olinux/sunxi/linux-sunxi/arch/arm/configs/.
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm a20_defconfig
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 uImage  
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 INSTALL_MOD_PATH=out modules
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 INSTALL_MOD_PATH=out modules_install

# Sunxi board configs
clone_or_pull sunxi-boards https://github.com/linux-sunxi
# Sunxi tools 
clone_or_pull sunxi-tools https://github.com/linux-sunxi
cd /olinux/sunxi/sunxi-tools/ && make
cd /olinux/sunxi/ && rm -f script.bin && ./sunxi-tools/fex2bin sunxi-boards/sys_config/a20/a20-olinuxino_lime.fex script.bin
cd /olinux/sunxi/ && chmod +x script.bin 
