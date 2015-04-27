#!/bin/sh

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
  -t		target directory for compilation			(default: /olinux/sunxi)
  -j		number of thread 					(default: 2)
  -l		change linux boot logo
  -c		cross compilation 

EOF
exit 1
}


THREADS=2
MAINTAINER="Emile"
MAINTAINERMAIL="emile@bleuchtang.fr"
REP=$(dirname $0)
TARGET=/olinux/sunxi

while getopts ":ob:t:l:c" opt; do
  case $opt in
    o)
      OFFLINE=yes
      ;;
    b)
      BOARD=$OPTARG
      ;;
    j)
      THREADS=$OPTARG
      ;;
    t)
      TARGET=$OPTARG
      ;;
    l)
      LOGO=$OPTARG
      ;;
    c)
      CROSS=yes
      ;;
    \?)
      show_usage
      ;;
  esac
done

. ${REP}/config_board.sh

clone_or_pull (){
  project=$1
  repo=$2
  name=$(echo $project |  sed 's/.git$//')
  if [ "$OFFLINE" ] ; then
    if [ -f ${TARGET}/$name/Makefile ] ; then
      cd ${TARGET}/$name/ && make clean && git checkout .
      return 0
    else
      return 0
    fi
  fi
  if [ -d ${TARGET}/$name/ ] ; then
    if [ -f ${TARGET}/$name/Makefile ] ; then
      cd ${TARGET}/$name/ && make clean && git checkout . && git pull
    else
      cd ${TARGET}/$name/ && git checkout . && git pull
    fi
  else
    git clone $repo/$project ${TARGET}/$name/
  fi
}

mkdir -p ${TARGET}/

## Sunxi u-boot
clone_or_pull u-boot.git http://git.denx.de
cd ${TARGET}/u-boot/
if [ ${CROSS} ] ; then
  make $U_BOOT_CONFIG ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
else
  make $U_BOOT_CONFIG CC=/usr/bin/gcc-4.7
fi
if [ "$LOGO" ] ; then
  cp ${REP}/logo/${LOGO}.bmp ${TARGET}/u-boot/tools/logos/denx.bmp
  sed -i -e 's/#define CONFIG_VIDEO_LOGO/#define CONFIG_VIDEO_LOGO\n#define CONFIG_VIDEO_BMP_LOGO/' ${TARGET}/u-boot/include/configs/sunxi-common.h
fi
if [ ${CROSS} ] ; then
  make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
else
  make CC=/usr/bin/gcc-4.7 
fi

# Linux kernel
clone_or_pull linux.git http://git.kernel.org/pub/scm/linux/kernel/git/torvalds
cd ${TARGET}/linux/
# igorpecovnik patch for debian package
patch -p1 < ${REP}/patch/packaging-next.patch
cp ${REP}/config/linux-sunxi.config ${TARGET}/linux/.config
if [ "$LOGO" ] ; then
  cp /${REP}/logo/${LOGO}.ppm ${TARGET}/linux/drivers/video/logo/logo_linux_clut224.ppm
fi
#make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- sunxi_defconfig
#make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig
if [ ${CROSS} ] ; then
  make -j${THREADS} ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- all zImage
else
  make -j${THREADS} CC=/usr/bin/gcc-4.7 all zImage
fi
# Install device tree blobs in separate package, link zImage to kernel image script
rm -f ${TARGET}/*.deb
if [ ${CROSS} ] ; then
  make -j1 deb-pkg KBUILD_DEBARCH=armhf ARCH=arm DEBFULLNAME="$MAINTAINER" DEBEMAIL="$MAINTAINERMAIL" CROSS_COMPILE=arm-linux-gnueabihf-
else
  make -j1 deb-pkg KBUILD_DEBARCH=armhf DEBFULLNAME="$MAINTAINER" DEBEMAIL="$MAINTAINERMAIL" CC=/usr/bin/gcc-4.7
fi

rm -rf ${TARGET}/config/boot.scr
mkimage -C none -A arm -T script -d ${REP}/config/boot.cmd ${TARGET}/boot.scr
