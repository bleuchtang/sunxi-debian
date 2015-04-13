ext2load mmc 0 0x46000000 /boot/zImage
ext2load mmc 0 0x49000000 /boot/board.dtb
setenv bootargs console=tty0 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mmcblk0p1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=8 consoleblank=0
bootz 0x46000000 - 0x49000000
