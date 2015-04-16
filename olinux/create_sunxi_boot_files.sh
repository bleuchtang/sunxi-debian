#/bin/sh

######################
# Sunxi  compilation #
######################

set -e
set -x

show_usage() {
cat <<EOF
# NAME

  $(basename $0) -- Script to build sunxi kernel and boot files

# OPTIONS

  -o		offline mode						(mandatory)
  -b		olinux board (a10lime, a20lime, a20lime2, a20micro) 	(default: a20lime)
  -t		number of thread 					(default: 2)
  -l		change linux boot logo

EOF
exit 1
}


THREADS=2
MAINTAINER="Emile"
MAINTAINERMAIL="emile@bleuchtang.fr"

while getopts ":ob:t:l:" opt; do
  case $opt in
    o)
      OFFLINE=yes
      ;;
    b)
      BOARD=$OPTARG
      ;;
    t)
      THREADS=$OPTARG
      ;;
    l)
      LOGO=$OPTARG
      ;;
    \?)
      show_usage
      ;;
  esac
done

source /olinux/config_board.sh

clone_or_pull (){
  project=$1
  repo=$2
  name=$(echo $project |  sed 's/.git$//')
  if [ "$OFFLINE" ] ; then
    if [ -f /olinux/sunxi/$name/Makefile ] ; then
      cd /olinux/sunxi/$name/ && make clean && git checkout .
      return 0
    else
      return 0
    fi
  fi
  if [ -d /olinux/sunxi/$name/ ] ; then
    if [ -f /olinux/sunxi/$name/Makefile ] ; then
      cd /olinux/sunxi/$name/ && make clean && git checkout . && git pull
    else
      cd /olinux/sunxi/$name/ && git checkout . && git pull
    fi
  else
    git clone $repo/$project /olinux/sunxi/$name/
  fi
}

mkdir -p /olinux/sunxi/

## Sunxi u-boot
clone_or_pull u-boot git://git.denx.de
cd /olinux/sunxi/u-boot/
make $U_BOOT_CONFIG ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
if [ "$LOGO" ] ; then
  cp /olinux/logo/${LOGO}.bmp /olinux/sunxi/u-boot/tools/logos/denx.bmp
  sed -i -e 's/#define CONFIG_VIDEO_LOGO/#define CONFIG_VIDEO_LOGO\n#define CONFIG_VIDEO_BMP_LOGO/' /olinux/sunxi/u-boot/include/configs/sunxi-common.h
fi
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

# Linux kernel
clone_or_pull linux.git git://git.kernel.org/pub/scm/linux/kernel/git/torvalds
cd /olinux/sunxi/linux/
# igorpecovnik patch for debian package
patch -p1 < /olinux/patch/packaging-next.patch
cp /olinux/config/linux-sunxi.config /olinux/sunxi/linux/.config
if [ "$LOGO" ] ; then
  cp /olinux/logo/${LOGO}.ppm /olinux/sunxi/linux/drivers/video/logo/logo_linux_clut224.ppm
fi
#make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- sunxi_defconfig
#make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig
make -j${THREADS} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- all zImage
# Install device tree blobs in separate package, link zImage to kernel image script
rm -f /olinux/sunxi/*.deb
make -j1 deb-pkg KBUILD_DEBARCH=armhf ARCH=arm DEBFULLNAME="$MAINTAINER" DEBEMAIL="$MAINTAINERMAIL" CROSS_COMPILE=arm-linux-gnueabihf-

rm -rf /olinux/sunxi/config/boot.scr
mkimage -C none -A arm -T script -d /olinux/config/boot.cmd /olinux/sunxi/boot.scr
