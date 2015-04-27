#!/bin/sh

case $BOARD in
  a20lime2)
    U_BOOT_CONFIG="A20-OLinuXino-Lime2_defconfig"
    DTB="sun7i-a20-olinuxino-lime2.dtb"
    ;;
  a20micro)
    U_BOOT_CONFIG="A20-OLinuXino_MICRO_defconfig"
    DTB="sun7i-a20-olinuxino-micro.dtb"
    ;;
  a10lime)
    U_BOOT_CONFIG="A10-OLinuXino-Lime_defconfig"
    DTB="sun7i-a20-olinuxino-lime.dtb"
    ;;
  *)
    U_BOOT_CONFIG="A20-OLinuXino-Lime_defconfig"
    DTB="sun7i-a20-olinuxino-lime.dtb"
    ;;
esac
