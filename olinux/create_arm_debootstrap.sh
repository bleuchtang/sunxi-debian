#/bin/sh

######################
#    Debootstrap     #
######################

show_usage() {
cat <<EOF
# NAME

  $(basename $0) -- Script to create a minimal deboostrap

# OPTIONS

  -d		debian release (wheezy, jessie) 	(default: wheezy)
  -a		add packages (wheezy)
  -n		name					(default: olinux)

EOF
exit 1
}

distro=wheezy
targetdir=/olinux/debootstrap
name=olinux

while getopts ":a:d:n:" opt; do
  case $opt in
    d)
      distro=$OPTARG
      ;;
    a)
      packages=$OPTARG
      ;;
    n)
      name=$OPTARG
      ;;
    \?)
      show_usage        
      ;;
  esac
done

rm -rf $targetdir && mkdir -p $targetdir

# install packages for debootstap
apt-get install --force-yes -y debootstrap dpkg-dev qemu binfmt-support qemu-user-static dpkg-cross

# Debootstrap
debootstrap --arch=armhf --foreign $distro $targetdir
update-binfmts --disable
mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
update-binfmts --enable
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
chroot $targetdir apt-get install -y --force-yes openssh-server ntp $packages

# Use dhcp on boot
cat <<EOT > $targetdir/etc/network/interfaces
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
EOT

# Configure tty
echo T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt100 >> $targetdir/etc/inittab

# add 'olinux' for root password
sed -i -e 's/root:*/root:$6$20Vo8onH$rsNB42ksO1i84CzCTt8e90ludfzIFiIGygYeCNlHYPcDOwvAEPGQQaQsK.GYU2IiZNHG.e3tRFizLmD5lnaHH/' $targetdir/etc/shadow

# add hostname 
echo $name > $targetdir/etc/hostname

# Remove useless files
chroot $targetdir apt-get clean
rm $targetdir/etc/resolv.conf
rm $targetdir/usr/bin/qemu-arm-static

