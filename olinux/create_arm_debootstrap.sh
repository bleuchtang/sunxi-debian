#/bin/sh

######################
#     Sunxi part     #
######################

# Sunxi u-boot
if [ -d /olinux/sunxi/u-boot-sunxi/ ] ; then 
  cd /olinux/sunxi/u-boot-sunxi/ && make clean && git pull 
else
  git clone -b sunxi https://github.com/linux-sunxi/u-boot-sunxi.git /olinux/sunxi/u-boot-sunxi
fi

cd /olinux/sunxi/u-boot-sunxi && make CROSS_COMPILE=arm-linux-gnueabihf A20-OLinuXino-Lime_config && make CROSS_COMPILE=arm-linux-gnueabihf-

# Sunxi kernel
if [ -d /olinux/sunxi/linux-sunxi/ ] ; then 
  cd /olinux/sunxi/linux-sunxi/ && make clean && git pull 
else
  git clone https://github.com/linux-sunxi/linux-sunxi -b stage/sunxi-3.4 /olinux/sunxi/linux-sunxi
fi

cp /olinux/a20_defconfig /olinux/sunxi/linux-sunxi/arch/arm/configs/.
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm a20_defconfig
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 uImage  
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 INSTALL_MOD_PATH=out modules
cd /olinux/sunxi/linux-sunxi/ && make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- -j2 INSTALL_MOD_PATH=out modules_install

# Sunxi fex2bin
if [ -d /olinux/sunxi/sunxi-tools/ ] ; then 
  cd /olinux/sunxi/sunxi-tools/ && make clean && git pull 
else
 git clone https://github.com/linux-sunxi/sunxi-tools /olinux/sunxi/sunxi-tools 
fi

cd /olinux/sunxi/sunxi-tools/ && make
cd /olinux/sunxi/ && ./sunxi-tools/fex2bin ../script.fex script.bin 
cd /olinux/sunxi/ && chown +x script.bin 

######################
#  Debootstrap part  #
######################

targetdir=/olinux/debootstrap
distro=wheezy
rm -rf $targetdir && mkdir -p $targetdir

# install packages for debootstap
apt-get install --force-yes -y debootstrap dpkg-dev qemu binfmt-support qemu-user-static dpkg-cross

mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
update-binfmts --enable

# Debootstrap
debootstrap --arch=armhf --foreign $distro $targetdir
cp /usr/bin/qemu-arm-static $targetdir/usr/bin/
cp /etc/resolv.conf $targetdir/etc
chroot $targetdir /debootstrap/debootstrap --second-stage 

# Configure debian apt repository
cat <<EOT > $targetdir/etc/apt/sources.list
deb http://ftp.fr.debian.org/debian $distro main contrib non-free
EOT
cat <<EOT > $targerdir/etc/apt/apt.conf.d/71-no-recommends
APT::Install-Suggests "0";
EOT
chroot $targetdir apt-get update 

# Add ssh server and ntp client
chroot $targetdir apt-get install -y --force-yes openssh-server ntp

# Use dhcp on boot
echo <<EOT > $targetdir/etc/network/interfaces
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
EOT

# Configure tty
echo T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt100 >> $targetdir/etc/inittab

# Remove useless files
chroot $targetdir apt-get clean
rm $targetdir/etc/resolv.conf
rm $targetdir/usr/bin/qemu-arm-static

