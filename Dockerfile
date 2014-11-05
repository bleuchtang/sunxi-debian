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

RUN apt-get install --force-yes -y gcc-4.7-arm-linux-gnueabihf ncurses-dev uboot-mkimage build-essential git

RUN ln -s /usr/bin/arm-linux-gnueabihf-gcc-4.7 /usr/bin/arm-linux-gnueabihf-gcc

RUN git clone -b sunxi https://github.com/linux-sunxi/u-boot-sunxi.git /u-boot-sunxi
RUN cd /u-boot-sunxi && make CROSS_COMPILE=arm-linux-gnueabihf A20-OLinuXino-Lime_config && make CROSS_COMPILE=arm-linux-gnueabihf-

# install packages for debootstrap
RUN apt-get install --force-yes -y debootstrap dpkg-dev qemu binfmt-support qemu-user-static dpkg-cross
