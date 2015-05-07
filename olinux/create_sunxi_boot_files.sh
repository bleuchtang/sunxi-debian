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
  -l		change linux boot logo                                  (default: false)
  -c		cross compilation                                       (default: false)
  -s 		use stable tarball (and not GIT tree)                   (default: false)

EOF
exit 1
}


THREADS=2
MAINTAINER=${MAINTAINER:-'Emile'}
MAINTAINERMAIL=${MAINTAINERMAIL:-'emile@bleuchtang.fr'}
REP=$(dirname $0)
TARGET=/olinux/sunxi
UBOOT_RELEASE=${UBOOT_RELEASE:-'ftp://ftp.denx.de/pub/u-boot/u-boot-latest.tar.bz2'}
LINUX_RELEASE=${LINUX_RELEASE:-'https://kernel.org/pub/linux/kernel/v4.x/linux-4.0.tar.xz'}

while getopts ":ob:t:l:cs" opt; do
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
    s)
      TARBALL=yes
      ;;
    \?)
      show_usage
      ;;
  esac
done

. ${REP}/config_board.sh

fetch (){
  project=$1
  repo=$2
  tarball_url=$3
  name=$(echo $project |  sed 's/.git$//')
  if [ ${TARBALL} ] ; then
    cd ${TARGET}
    archive=$(basename $tarball_url)
    format=$(basename "${archive##*.}")
    case $format in
      'gz')  tar_opts='xzf' ;;
      'xz')  tar_opts='xf'  ;;
      'bz2') tar_opts='xjf' ;;
    esac
    wget $tarball_url -O $archive
    mkdir -p tmp
    tar $tar_opts $archive -C tmp/
    mkdir -p $name
    mv tmp/$name*/* $name
    rm -rf tmp/
    return 0
  fi
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
fetch u-boot.git http://git.denx.de $UBOOT_RELEASE
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
fetch linux.git http://git.kernel.org/pub/scm/linux/kernel/git/torvalds $LINUX_RELEASE
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
