olinux-lime2
==========

Bootstrap a minimal debian for olinuxino-a20-lime2

Thanks to [lukas2511](https://github.com/lukas2511/olinuxino-a20-micro) for
quick bootstrap.

# Build minimal U-boot

```shell
sudo docker pull debian:stable
git clone https://github.com/bleuchtang/olinux-lime2
cd olinux-lime2 && sudo docker build -t debian/olinux .
```

# Build minimal arm debootstrap

We cannot perform a debootstrap in dockerfile bacause dockerfile doesn't accept
privileged mode. For more details see [docker
issue](https://github.com/docker/docker/issues/1916) 

```shell
sudo docker run --privileged -i -t -v $(pwd)/olinux/:/olinux/ debian/olinux sh ./olinux/create_arm_debootstrap.sh
```

You shoud have both debootstrap and u-boot-sunxi directories in olinux/

# Boot

TODO

# Install on a sdcard

TODO

# Some links:

## You probably want to Build your own docker image;

- Because it's quick and easy; tutorial [here](http://www.aossama.com/build-debian-docker-image-from-scratch/)
- Because you shoudn't trust regitry images; demonstration [here](https://joeyh.name/blog/entry/docker_run_debian/) 

# External links 
- [how-to-create-bare-minimum-debian-wheezy-rootfs-from-scratch](http://olimex.wordpress.com/2014/07/21/how-to-create-bare-minimum-debian-wheezy-rootfs-from-scratch/)
- [building-a-pure-debian-armhf-rootfs/](http://blog.night-shade.org.uk/2013/12/building-a-pure-debian-armhf-rootfs/)
- [Run-ARM-Binaries-in-Your-Docker-Container-Using-Boot2Docker](http://www.hnwatcher.com/r/1526487/Run-ARM-Binaries-in-Your-Docker-Container-Using-Boot2Docker)
- [running-arm-linux-on-your-desktop](http://tinkering-is-fun.blogspot.fr/2009/12/running-arm-linux-on-your-desktop-pc_12.html)
- [debian-wheezy-rootfs](http://www.yoovant.com/debian-wheezy-rootfs/)
- [install-debian-wheezy-on-your-banana-pi](http://cbwebs.de/single-board-computer/banana-pi/install-debian-wheezy-on-your-banana-pi/)
- [Bootstrapping_Debian](https://linux-sunxi.org/Mainline_Debian_HowTo#Bootstrapping_Debian)
- [Allwinner](https://wiki.debian.org/InstallingDebianOn/Allwinner)
