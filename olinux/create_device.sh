#!/bin/bash

set -e

show_usage() {
cat <<EOF
# NAME

  $(basename $0) -- Script format device and copy rootfs on it

# OPTIONS

  -d		device name (img, /dev/sdc, /dev/mmc)	(mandatory)
  -s		size of img in MB		 	(mandatory only for img device option)

EOF
exit 1
}

DEST=./olinux
MNT=/mnt
IMAGE=olinux.img

while getopts "s:d:" opt; do
  case $opt in
    d)
      DEVICE=$OPTARG
      ;;
    s)
      SDSIZE=$OPTARG
      ;;
    \?)
      show_usage
      ;;
  esac
done

if [ -z $DEVICE ] ; then
  show_usage
fi

if [ "$DEVICE" == "img" ] && [ -z $SDSIZE ] ; then
  show_usage
fi

if [ "${DEVICE}" == "img" ] ; then
  echo "- Create image."
  rm -f olinux/$IMAGE
  # create image file
  dd if=/dev/zero of=olinux/$IMAGE bs=1MB count=$SDSIZE status=noxfer >/dev/null 2>&1
  
  # find first avaliable free device
  DEVICE=$(losetup -f)
  TYPE="loop"
  
  # mount image as block device
  losetup $DEVICE $DEST/$IMAGE >/dev/null 2>&1
  
  sync
  
fi

# create one partition starting at 2048 which is default
echo "- Partitioning"
parted --script -a optimal $DEVICE unit GB mklabel msdos 
parted --script -a optimal $DEVICE unit GB mkpart primary ext4 2048s 99%
parted --script -a optimal $DEVICE unit GB align-check optimal 1

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
# copy debootstrap
cp -ar olinux/debootstrap/* $MNT/
sync

echo "- Write sunxi-with-spl"
dd if=olinux/sunxi/u-boot/u-boot-sunxi-with-spl.bin of=${DEVICE} bs=1024 seek=8 >/dev/null 2>&1

echo "- Umount"
if [ "${TYPE}" == "loop" ] ; then
  umount $MNT
  losetup -d $DEVICE
else
  umount $MNT
fi
