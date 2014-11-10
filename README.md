olinux-a20-lime2
==========

Bootstrap a minimal debian for olinuxino-a20-lime2

Thanks to [lukas2511](https://github.com/lukas2511/olinuxino-a20-micro) for
quick bootstrap.

# Build docker image

```shell
sudo docker pull debian:stable
git clone https://github.com/bleuchtang/olinuxino-a20-lime2
cd olinuxino-a20-lime2 && sudo docker build -t debian/olinux .
```

# Build minimal arm debootstrap

We cannot perform a debootstrap in dockerfile because dockerfile doesn't accept
privileged mode. For more details see [docker
issue](https://github.com/docker/docker/issues/1916) 

```shell
sudo docker run --privileged -i -t -v $(pwd)/olinux/:/olinux/ debian/olinux sh ./olinux/create_arm_debootstrap.sh
```

# Build sunxi kernel and boot files

You shoud have both debootstrap and sunxi directories in olinux/
```shell
sudo docker run --privileged -i -t -v $(pwd)/olinux/:/olinux/ debian/olinux sh ./olinux/create_sunxi_boot_files.sh
```

# Install on a sd card

## Partitioning

```shell
mmc=/dev/sdc
parted -s ${mmc} mklabel msdos
parted -a optimal ${mmc} mkpart primary fat32 1 16MiB
parted -a optimal ${mmc} mkpart primary fat32 16MiB 100%
mkfs.fat -F 32 ${mmc}1
mkfs.ext4 ${mmc}2
```

## Installation

```shell
dd if=olinux/sunxi/u-boot-sunxi/u-boot-sunxi-with-spl.bin of=${mmc} bs=1024 seek=8
mount ${mmc}1 /media/usb/
cp olinux/sunxi/script.bin /media/usb/
cp olinux/sunxi/linux-sunxi/arch/arm/boot/uImage /media/usb/
umount /media/usb
mount ${mmc}2 /media/usb/
cp -r olinux/debootstrap/* /media/usb/
sync
rm -rf /media/usb/lib/firmware/
cp -rfv olinux/sunxi/linux-sunxi/out/lib/firmware/ /media/usb/lib/
sync
rm -rf /media/usb/lib/modules/
cp -rfv olinux/sunxi/linux-sunxi/out/lib/modules/* /media/usb/lib/modules
sync
```

# TODO

- change _Install on a sd card_ to a script ?

# Some links:

## You probably want to Build your own docker image

- Because it's quick and easy; tutorial [here](http://www.aossama.com/build-debian-docker-image-from-scratch/)
- Because you shoudn't trust regitry images; demonstration [here](https://joeyh.name/blog/entry/docker_run_debian/) 

# External links 
- [how-to-create-bare-minimum-debian-wheezy-rootfs-from-scratch](http://olimex.wordpress.com/2014/07/21/how-to-create-bare-minimum-debian-wheezy-rootfs-from-scratch/)
- [building-a-pure-debian-armhf-rootfs](http://blog.night-shade.org.uk/2013/12/building-a-pure-debian-armhf-rootfs/)
- [Run-ARM-Binaries-in-Your-Docker-Container-Using-Boot2Docker](http://www.hnwatcher.com/r/1526487/Run-ARM-Binaries-in-Your-Docker-Container-Using-Boot2Docker)
- [running-arm-linux-on-your-desktop](http://tinkering-is-fun.blogspot.fr/2009/12/running-arm-linux-on-your-desktop-pc_12.html)
- [debian-wheezy-rootfs](http://www.yoovant.com/debian-wheezy-rootfs/)
- [install-debian-wheezy-on-your-banana-pi](http://cbwebs.de/single-board-computer/banana-pi/install-debian-wheezy-on-your-banana-pi/)
- [Bootstrapping_Debian](https://linux-sunxi.org/Mainline_Debian_HowTo#Bootstrapping_Debian)
- [Allwinner](https://wiki.debian.org/InstallingDebianOn/Allwinner)
