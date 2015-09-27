#!/bin/bash

set -e
set -x

show_usage() {
cat <<EOF
# NAME

  $(basename $0) -- Script format device and copy rootfs on it

# OPTIONS

  -d		device name (img, /dev/sdc, /dev/mmc)	(mandatory)
  -s		size of img in MB		 	(mandatory only for img device option)
  -t		final image name			(default: /olinux/olinux.img)
  -b		debootstrap directory, .img or tarball	(default: /olinux/debootstrap)
  -u		uboot file				(default: /olinux/sunxi/u-boot/u-boot-sunxi-with-spl.bin)
  -e		encrypt partition			(default: false)

EOF
exit 1
}

TARGET=./olinux/olinux.img
MNT1=/mnt/dest
MNT2=/mnt/source
DEB_DIR=./olinux/debootstrap
UBOOT_FILE=./olinux/sunxi/u-boot/u-boot-sunxi-with-spl.bin

while getopts ":s:d:t:b:u:e" opt; do
  case $opt in
    d)
      DEVICE=$OPTARG
      ;;
    s)
      IMGSIZE=$OPTARG
      ;;
    t)
      TARGET=$OPTARG
      ;;
    b)
      DEB_DIR=$OPTARG
      ;;
    u)
      UBOOT_FILE=$OPTARG
      ;;
    e)
      ENCRYPT=yes
      ;;
    \?)
      show_usage
      ;;
  esac
done

if [ -z $DEVICE ] ; then
  show_usage
fi

if [ "$DEVICE" = "img" ] && [ -z $IMGSIZE ] ; then
  show_usage
fi

mkdir -p $MNT1
mkdir -p $MNT2

if [ "${DEVICE}" = "img" ] ; then
  echo "- Create image."
  rm -f ${TARGET}
  # create image file
  dd if=/dev/zero of=${TARGET} bs=1MB count=$IMGSIZE status=noxfer >/dev/null 2>&1

  # find first avaliable free device
  DEVICE=$(losetup -f)
  IMGSIZE="100%"
  TYPE="loop"

  # mount image as block device
  losetup $DEVICE ${TARGET}

  sync

elif [ ! -z $IMGSIZE ] ; then
  IMGSIZE=${IMGSIZE}"MiB"
else
  IMGSIZE="100%"
fi

if [ -z $ENCRYPT ] ; then
  # create one partition starting at 2048 which is default
  echo "- Partitioning"
  parted --script $DEVICE mklabel msdos
  parted --script $DEVICE mkpart primary ext4 2048s ${IMGSIZE}
  parted --script $DEVICE align-check optimal 1
else
  parted --script $DEVICE mklabel msdos
  parted --script $DEVICE mkpart primary ext4 2048s 512MB
  parted --script $DEVICE mkpart primary ext4 512MB ${IMGSIZE}
  parted --script $DEVICE align-check optimal 1
fi

if [ "${TYPE}" = "loop" ] ; then
  DEVICEP1=${DEVICE}p1
else
  DEVICEP1=${DEVICE}1
fi

echo "- Formating"
# create filesystem
mkfs.ext4 $DEVICEP1 >/dev/null 2>&1

# tune filesystem
tune2fs -o journal_data_writeback $DEVICEP1 >/dev/null 2>&1

if [ -z $ENCRYPT ] ; then
  echo "- Mount filesystem"
  # mount image to already prepared mount point
  mount -t ext4 $DEVICEP1 $MNT1
else
  DEVICEP2=${DEVICE}2
  cryptsetup -y -v luksFormat $DEVICEP2
  cryptsetup luksOpen $DEVICEP2 olinux
  mkfs.ext4 /dev/mapper/olinux >/dev/null 2>&1
  echo "- Mount filesystem"
  # mount image to already prepared mount point
  mount -t ext4 /dev/mapper/olinux $MNT1
  mkdir	$MNT1/boot
  mount -t ext4 $DEVICEP1 $MNT1/boot
fi  

echo "- Copy bootstrap files"
if [ -d ${DEB_DIR} ] ; then
  # Assume that directly the debootstrap directory
  cp -ar ${DEB_DIR}/* $MNT1/
elif [[ `file ${DEB_DIR} | grep 'DOS/MBR'` ]] ; then
  # Assume that is a .img file
  # find first avaliable free device
  DEVICE1=$(losetup -f)

  # mount image as block device
  losetup -o 1048576 $DEVICE1 ${DEB_DIR}
  mount ${DEVICE1} $MNT2/
  cp -ar $MNT2/* $MNT1/
else 
  # Assume that is a tarball file
  tar --same-owner --preserve-permissions -xvf ${DEB_DIR} -C $MNT1/ .
fi
sync

echo "- Write sunxi-with-spl"
dd if=${UBOOT_FILE} of=${DEVICE} bs=1024 seek=8 >/dev/null 2>&1
sync

if [ "${DEVICE}" = "img" ] ; then
  echo "- Sfill"
  sfill -z -l -l -f $MNT
fi

echo "- Umount"
if [ "${TYPE}" = "loop" ] ; then
  echo "- Sfill"
  sfill -z -l -l -f $MNT1
  umount $MNT1
  losetup -d $DEVICE
else
  if [ -z $ENCRYPT ] ; then
    umount $MNT1
  else
    umount $MNT1/boot
    umount $MNT1
    cryptsetup luksClose olinux 
  fi
  if $(file ${DEB_DIR} | grep 'DOS/MBR') ; then
    umount $MNT2
    losetup -d $DEVICE1
  fi	  
fi
