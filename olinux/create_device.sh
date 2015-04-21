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
  -t		image name				(default: /olinux/olinux.img)
  -b		debootstrap directory			(default: /olinux/debootstrap)
  -u		uboot file				(default: /olinux/sunxi/u-boot/u-boot-sunxi-with-spl.bin)

EOF
exit 1
}

TARGET=./olinux/olinux.img
MNT=/mnt
DEB_DIR=./olinux/debootstrap
UBOOT_FILE=./olinux/sunxi/u-boot/u-boot-sunxi-with-spl.bin

while getopts ":s:d:t:b:u:" opt; do
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
    \?)
      show_usage
      ;;
  esac
done

if [ -z $DEVICE ] ; then
  show_usage
fi

if [ "$DEVICE" == "img" ] && [ -z $IMGSIZE ] ; then
  show_usage
fi

if [ "${DEVICE}" == "img" ] ; then
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

# create one partition starting at 2048 which is default
echo "- Partitioning"
parted --script $DEVICE mklabel msdos 
parted --script $DEVICE mkpart primary ext4 2048s ${IMGSIZE}
parted --script $DEVICE align-check optimal 1

if [ "${TYPE}" == "loop" ] ; then
  DEVICEP1=${DEVICE}p1
else
  DEVICEP1=${DEVICE}1
fi

echo "- Formating"
# create filesystem
mkfs.ext4 $DEVICEP1 >/dev/null 2>&1

# tune filesystem
tune2fs -o journal_data_writeback $DEVICEP1 >/dev/null 2>&1

echo "- Mount filesystem"
# mount image to already prepared mount point
mount -t ext4 $DEVICEP1 $MNT

echo "- Copy bootstrap files"
if [ -d ${DEB_DIR} ] ; then
  cp -ar ${DEB_DIR}/* $MNT/
else
  # Assume that is a tarball file
  tar xvf ${DEB_DIR} -C $MNT/ .
fi
sync

echo "- Write sunxi-with-spl"
dd if=${UBOOT_FILE} of=${DEVICE} bs=1024 seek=8 >/dev/null 2>&1
sync

echo "- Umount"
if [ "${TYPE}" == "loop" ] ; then
  umount $MNT
  losetup -d $DEVICE
else
  umount $MNT
fi
