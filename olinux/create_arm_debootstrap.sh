#/bin/sh

######################
#  Debootstrap part  #
######################

targetdir=/olinux/debootstrap
distro=wheezy
rm -rf $targetdir && mkdir -p $targetdir

# install packages for debootstap
apt-get install --force-yes -y debootstrap dpkg-dev qemu binfmt-support qemu-user-static dpkg-cross

update-binfmts --disable
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

