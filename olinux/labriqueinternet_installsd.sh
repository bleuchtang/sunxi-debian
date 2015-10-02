#!/bin/bash

set -e


###############
### HELPERS ###
###############

function show_usage() {
  echo -e " MANDATORY" >&2
  echo -e " \t-s SD card (e.g. /dev/sdb, /dev/mmcblk0)\n" >&2
  echo -e " OPTIONAL" >&2
  echo -e " \t-f Debian/YunoHost image file (.img or .img.tar.xz)" >&2
  echo -e " \t-c MD5 checksums file (e.g. MD5SUMS)" >&2
  echo -e " \t-e Install an encrypted file system" >&2
  echo -e " \t-2 Install an image for LIME2 (default: LIME)" >&2
  echo -e " \t-h Show this help\n" >&2
}

function exit_error() {
  if [ ! -z "${1}" ]; then
    echo "[ERR] $1" >&2
  fi

  if [ "${2}" == usage ]; then
    echo && show_usage
  fi

  exit 1
}

function exit_usage() {
  exit_error "${1}" usage
}

function exit_normal() {
  exit 0
}

function info() {
  echo "[INFO] ${1}" >&2
}


##########################
### CHECKING FUNCTIONS ###
##########################

function check_args() {
  if [[ ! -b "${opt_sdcardpath}" || ! ( "${opt_sdcardpath}" =~ ^/dev/sd[a-z]$ ||  "${opt_sdcardpath}" =~ ^/dev/mmcblk[0-9]$ ) ]]; then
    exit_usage "-s must be a block device corresponding to your SD card"
  fi
  
  if [ ! -z "${opt_md5path}" -a ! -r "${opt_md5path}" ]; then
    exit_usage "file given to -c cannot be read"
  fi
  
  if [[ ! -z "${opt_imgpath}" ]]; then
    if [[ ! "${opt_imgpath}" =~ .img$ && ! "${opt_imgpath}" =~ .img.tar.xz$ ]]; then
      exit_usage "Filename given to -f must end by .img or .img.tar.xz"
    fi
  
    if [[ "${opt_imgpath}" =~ _encryptedfs_ ]]; then
      info "Option -e automatically set, based on the filename given to -f"
      opt_encryptedfs=true
  
    elif $opt_encryptedfs; then
      exit_usage "Filename given to -f does not contain _encrypted_ in its name, but -e was set"
    fi
  
    if [[ "${opt_imgpath}" =~ LIME2 ]]; then
      info "Option -2 automatically set, based on the filename given to -f"
      opt_lime2=true
  
    elif $opt_lime2; then
      exit_usage "Filename given to -f does not contain LIME2 in its name, but -2 was set"
    fi
  fi
}

function check_bins() {
  local bins=(wget tar mountpoint cryptsetup parted mkfs.ext4 tune2fs losetup)

  if ! which sudo &> /dev/null; then
    exit_error "sudo command is required"
  fi

  for i in "${bins[@]}"; do
    if ! sudo which "${i}" &> /dev/null; then
      exit_error "${i} command is required"
    fi
  done
}


#################
### FUNCTIONS ###
#################

function clean() {
  local mountpoints=("${olinux_mountpoint}/boot" "${olinux_mountpoint}" "${files_path}")

  for i in "${mountpoints[@]}"; do
    if mountpoint -q "${i}"; then
      sudo umount "${i}"
    fi
  done

  if [ -b /dev/mapper/olinux ]; then
    sudo cryptsetup luksClose olinux 
  fi

  [ ! -z "${tmp_dir}" ] && rm -r "${tmp_dir}"
}

function download_img() {
  $opt_lime2 && local urlpart_lime2=2
  $opt_encryptedfs && local urlpart_encryptedfs=_encryptedfs
  
  local tar_name=$(labriqueinternet_A20LIME${urlpart_lime2}${urlpart_encryptedfs}_latest_${deb_version}.img.tar.xz)

  if ! wget -s "${url_base}${tar_name}" -P "${tmp_dir}"; then
    exit_error "Image download failed"
  fi

  img_path="${tmp_dir}/${tar_name}"
}

function untar_img() {
  tar xf "${img_path}" -C "${tmp_dir}"

  # Should not have more than 1 line, but, you know...
  img_path=$(find "${tmp_dir}" -name *.img | head -n1) 
}

function download_md5() {
  if ! wget -s "${url_base}MD5SUMS" -P "${tmp_dir}"; then
    exit_error "MD5SUMS file download failed"
  fi

  md5_path="${tmp_dir}/MD5SUMS"
}

function check_md5() {
  if ! md5sum --quiet "${tmp_dir}/${tar_name}" -c "${md5_path}"; then
    exit_error "Checksum error"
  fi
}


######################
### CORE FUNCTIONS ###
######################

function install_encrypted() {
  local partition1="${opt_sdcardpath}1"
  local partition2="${opt_sdcardpath}2"
  local board=a20lime
  local uboot=A20-OLinuXino-Lime

  mkdir "${files_path}" "${olinux_mountpoint}"

  $opt_lime2 && board+=2
  $opt_lime2 && uboot+=2

  local sunxispl_path="${olinux_mountpoint}/usr/lib/u-boot/${uboot}/u-boot-sunxi-with-spl.bin"

  if [[ "${opt_sdcardpath}" =~ /mmcblk[0-9]$ ]]; then
    partition1="${opt_sdcardpath}p1"
    partition2="${opt_sdcardpath}p2"
  fi

  sudo parted --script "${opt_sdcardpath}" mklabel msdos
  sudo parted --script "${opt_sdcardpath}" mkpart primary ext4 2048s 512MB
  sudo parted --script "${opt_sdcardpath}" mkpart primary ext4 512MB 100%
  sudo parted --script "${opt_sdcardpath}" align-check optimal 1

  if [ ! -b "${partition1}" -o ! -b "${partition2}" ]; then
    exit_error "Unable to detect created partitions"
  fi

  sudo mkfs.ext4 "${partition1}"
  sudo tune2fs -o journal_data_writeback "${partition1}" &> /dev/null

  sudo cryptsetup -y -v luksFormat "${partition2}"
  sudo cryptsetup luksOpen "${partition2}" olinux

  if [ ! -b /dev/mapper/olinux ]; then
    exit_error "Partition decryption failed"
  fi

  sudo mkfs.ext4 /dev/mapper/olinux
  sudo mount -t ext4 /dev/mapper/olinux "${olinux_mountpoint}"
  sudo mkdir "${olinux_mountpoint}/boot"
  sudo mount -t ext4 "${partition1}" "${olinux_mountpoint}/boot"

  local lodev=$(sudo losetup -f)

  if [ -z "${lodev}" ]; then
    exit_error "Loopback setup failed"
  fi

  sudo losetup -o 1048576 "${lodev}" "${img_path}"
  sudo mount "${lodev}" "${files_path}"
  sudo cp -a ${files_path}/* "${olinux_mountpoint}"

  if [ ! -f "${sunxispl_path}" ]; then
    exit_error "u-boot-sunxi-with-spl.bin unavailable"
  fi

  sudo dd "if=${sunxispl_path}" "of=${opt_sdcardpath}" bs=1024 seek=8 &> /dev/null
  sudo sync
}

function install_clear() {
  sudo dd "if=${img_path}" of="${opt_sdcardpath}" bs=1M &> /dev/null
  sudo sync
}


########################
### GLOBAL VARIABLES ###
########################

opt_encryptedfs=false
opt_lime2=false
img_path=false
url_base=http://repo.labriqueinter.net/
deb_version=jessie
tmp_dir=$(mktemp -dp /tmp/ labriqueinternet-installsd-XXXXX)
olinux_mountpoint="${tmp_dir}/olinux_mountpoint"
files_path="${tmp_dir}/files"


##############
### SCRIPT ###
##############

trap clean ERR
trap clean EXIT

while getopts "f:s:c:e2:h" opt; do
  case $opt in
    f) opt_imgpath=$OPTARG ;;
    c) opt_md5path=$OPTARG ;;
    s) opt_sdcardpath=$OPTARG ;;
    e) opt_encryptedfs=true ;;
    2) opt_lime2=true ;;
    h) exit_usage ;;
    \?) exit_usage "Invalid option: -$OPTARG" ;;
    :) exit_usage "Option -$OPTARG requires an argument" ;;
  esac
done

check_args
check_bins

img_path=$opt_imgpath
md5_path=$opt_md5path

if [ -z "${img_path}" ]; then
  info "Downloading Debian/YunoHost image"
  download_img

  if [ -z "${md5_path}" ]; then
    info "Downloading MD5SUMS"
    download_md5
  fi
fi

if [[ "${img_path}" =~ .img.tar.xz$ ]]; then
  info "Decompressing Debian/YunoHost image"
  untar_img
fi

if [ ! -z "${md5_path}" ]; then
  info "Checking MD5 message digest"
  check_md5
fi

if $opt_encryptedfs; then
  info "Installing encrypted SD card"
  install_encrypted
else
  info "Installing SD card"
  install_clear
fi

info "Done"

exit_normal
