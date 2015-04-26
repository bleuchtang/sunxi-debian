Debian-Sunxi
==========

Bootstrap a minimal debian rootfs with sunxi kernel and boot files. For now
only 4 olinuxino boards are available. All scripts in this repository are
generic so it's easy to add a new boad. Please make a pull request if you
create and test a new board. I need reviewers for olinuxino lime2 and micro
olinuxino boards.

Thanks to [lukas2511](https://github.com/lukas2511/olinuxino-a20-micro) for
quick bootstrap, and [igorpecovnik](https://github.com/igorpecovnik/lib) for
some useful scripts.

# Build docker image

```shell
git clone --depth=1 https://github.com/bleuchtang/sunxi-debian
cd sunxi-debian && sudo docker build -t debian:olinux .
```

# Build sunxi kernel and boot files

To build sunxi kernel and boot files run:

```shell
sudo docker run --privileged -i -t -v $(pwd)/olinux/:/olinux/ debian:olinux bash /olinux/create_sunxi_boot_files.sh -c
```

Optional arguments:
+ -o offline mode; doesn't pull repositories so you should have run the script once without this option
+ -b <type> board type (lime,lime2,micro) default is A20 lime
+ -t <number> number of thread for compilation
+ -l change linux logo on u-boot and kernel

# Build minimal arm debootstrap

We cannot perform a debootstrap in dockerfile because dockerfile doesn't accept
privileged mode. For more details see [docker issue](https://github.com/docker/docker/issues/1916)

To build the minimal debian rootfs with the kernel previously build:

```shell
sudo docker run --privileged -i -t -v $(pwd)/olinux/:/olinux/ debian:olinux bash /olinux/create_arm_debootstrap.sh -i olinux/sunxi -c
```

Optional arguments:
+ -n <name> hostnane
+ -a <packages> add additional packages
+ -d <release> debian release (wheezy, jessie...)
+ -i install kernel previously build
+ -y install yunohost with chroot (testing)

# Install on a SD card

## Setup SD card device

Find your device card (with dmesg for instance). Call create_device script with
this device in parameter. This script install debootstrap previously build.

```shell
sudo bash olinux/create_device.sh -d /dev/sdc
```

You can directly create a image file that you can copy after on your sd card or share with others.

```shell
sudo bash olinux/create_device.sh -d img -s 500
```

# Login to your Olimex

Find IP and ssh on it! (password: olinux)

```shell
ssh root@mybox
```

# Some links/tips:

## Convert bmp logo to ppm

```shell

bmptoppm Labriqueinter.net.bmp > Labriqueinter.net.ppm
ppmquant 224 Labriqueinter.net.ppm > Labriqueinter.net224.ppm
nmnoraw Labriqueinter.net224.ppm > Labriqueinter.net.ppm
```

## You probably want to Build your own docker image

- Because it's quick and easy; tutorial [here](http://www.aossama.com/build-debian-docker-image-from-scratch/)
- Because you shouldn't trust registry images; demonstration [here](https://joeyh.name/blog/entry/docker_run_debian/)

## External links

- [how-to-create-bare-minimum-debian-wheezy-rootfs-from-scratch](http://olimex.wordpress.com/2014/07/21/how-to-create-bare-minimum-debian-wheezy-rootfs-from-scratch/)
- [building-a-pure-debian-armhf-rootfs](http://blog.night-shade.org.uk/2013/12/building-a-pure-debian-armhf-rootfs/)
- [Run-ARM-Binaries-in-Your-Docker-Container-Using-Boot2Docker](http://www.hnwatcher.com/r/1526487/Run-ARM-Binaries-in-Your-Docker-Container-Using-Boot2Docker)
- [running-arm-linux-on-your-desktop](http://tinkering-is-fun.blogspot.fr/2009/12/running-arm-linux-on-your-desktop-pc_12.html)
- [debian-wheezy-rootfs](http://www.yoovant.com/debian-wheezy-rootfs/)
- [install-debian-wheezy-on-your-banana-pi](http://cbwebs.de/single-board-computer/banana-pi/install-debian-wheezy-on-your-banana-pi/)
- [Bootstrapping_Debian](https://linux-sunxi.org/Mainline_Debian_HowTo#Bootstrapping_Debian)
- [Allwinner](https://wiki.debian.org/InstallingDebianOn/Allwinner)
