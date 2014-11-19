#/bin/sh

######################
# Sunxi  compilation #
######################

show_usage() {
cat <<EOF
# NAME

  $(basename $0) -- Script to build sunxi kernel and boot files

# OPTIONS

  -o		offline mode				(mandatory) 
  -t		olinux type (lime, lime2, micro) 	(default: lime)

EOF
exit 1
}

while getopts ":ot:" opt; do
  case $opt in
    o)
      offline=$OPTARG
      ;;
    t)
      olinux=$OPTARG
      ;;
    \?)
      show_usage        
      ;;
  esac
done

clone_or_pull (){
  project=$1
  repo=$2
  name=$(echo $project |  sed 's/.git$//')
  if [ "$offline" ] ; then
    cd /olinux/sunxi/$name/ && make clean
    return 0
  fi 
  if [ -d /olinux/sunxi/$name/ ] ; then 
    cd /olinux/sunxi/$name/ && make clean && git pull --depth 1 
  else
    git clone --depth 1 $repo/$project /olinux/sunxi/$name/
  fi
}

if [ "$olinux" = "lime2" ] ; then
  u_boot_config=A20-OLinuXino-Lime2_defconfig
  sunxi_board_config="a20/a20-olinuxino_lime2.fex"
elif [ "$olinux" = "micro" ] ; then
  u_boot_config=A20-OLinuXino_MICRO_defconfig
  sunxi_board_config="a20/a20-olinuxino_micro.fex"
else
  u_boot_config=A20-OLinuXino-Lime_defconfig
  sunxi_board_config="a20/a20-olinuxino_lime.fex"
fi

mkdir -p /olinux/sunxi/

# Sunxi u-boot
#clone_or_pull u-boot-sunxi
clone_or_pull u-boot.git git://git.denx.de
cd /olinux/sunxi/u-boot && make CROSS_COMPILE=arm-linux-gnueabihf $u_boot_config && make CROSS_COMPILE=arm-linux-gnueabihf-

# Sunxi kernel
clone_or_pull linux-sunxi.git https://github.com/linux-sunxi
cp /olinux/a20_defconfig /olinux/sunxi/linux-sunxi/arch/arm/configs/.
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm a20_defconfig
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 uImage  
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 INSTALL_MOD_PATH=out modules
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 INSTALL_MOD_PATH=out modules_install

# Sunxi board configs
clone_or_pull sunxi-boards.git https://github.com/linux-sunxi
# Sunxi tools 
clone_or_pull sunxi-tools.git https://github.com/linux-sunxi
cd /olinux/sunxi/sunxi-tools/ && make
cd /olinux/sunxi/ && rm -f script.bin && ./sunxi-tools/fex2bin sunxi-boards/sys_config/$sunxi_board_config script.bin
cd /olinux/sunxi/ && chmod +x script.bin 
