FROM debian:stable
#FROM emile/wheezy
MAINTAINER Émile_morel

# U-boot part 
RUN echo deb http://www.emdebian.org/debian unstable main > /etc/apt/sources.list.d/emdebian.list
ENV DEBIAN_FRONTEND noninteractive 
ENV DEBCONF_NONINTERACTIVE_SEEN true 
ENV LC_ALL C 
ENV LANGUAGE C 
ENV LANG C 
RUN apt-get update
RUN apt-get install --force-yes -y emdebian-archive-keyring
RUN apt-get update

RUN apt-get install --force-yes -y gcc-4.7-arm-linux-gnueabihf ncurses-dev uboot-mkimage build-essential git vim libusb-1.0-0-dev 

RUN ln -s /usr/bin/arm-linux-gnueabihf-gcc-4.7 /usr/bin/arm-linux-gnueabihf-gcc
#RUN mkdir -p /olinux
#VOLUME /home/emile/dev/github/olinuxino-a20-lime2/olinux /olinux
#RUN mkdir -p /olinux/sunxi

#RUN git clone -b sunxi https://github.com/linux-sunxi/u-boot-sunxi.git /olinux/sunxi/u-boot-sunxi
#RUN cd /olinux/sunxi/u-boot-sunxi && make CROSS_COMPILE=arm-linux-gnueabihf A20-OLinuXino-Lime_config && make CROSS_COMPILE=arm-linux-gnueabihf-
#
#RUN git clone https://github.com/linux-sunxi/linux-sunxi -b stage/sunxi-3.4 /olinux/sunxi/linux-sunxi
#RUN cp /olinux/a20_defconfig /olinux/sunxi/linux-sunxi/arch/arm/configs/.
#RUN cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm a20_defconfig
#RUN cd /olinux/sunxi/linux-sunxi/ && patch -p0 < ../../sunxi-i2c.patch
#RUN cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- uImage  
#RUN cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=out modules
#RUN cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=out modules_install

# install packages for debootstrap
RUN apt-get install --force-yes -y debootstrap dpkg-dev qemu binfmt-support qemu-user-static dpkg-cross
