#/bin/bash

######################
#    Debootstrap     #
######################

set -e

show_usage() {
cat <<EOF
# NAME

  $(basename $0) -- Script to create a minimal deboostrap

# OPTIONS

  -d		debian release (wheezy, jessie) 	(default: wheezy)
  -b		olinux board (see config_board.sh) 	(default: a20lime)
  -a		add packages to deboostrap
  -n		hostname				(default: olinux)
  -t		target directory for debootstrap	(default: /olinux/debootstrap)
  -i		install sunxi kernel files; you should have build them before.
  -y		install yunohost (doesn't work with cross debootstrap)
  -c		cross debootstrap 
  -p		use aptcacher proxy 

EOF
exit 1
}

DEBIAN_RELEASE=wheezy
TARGET_DIR=/olinux/debootstrap
DEB_HOSTNAME=olinux
REP=$(dirname $0)

while getopts ":a:b:d:n:t:i:ycp" opt; do
  case $opt in
    d)
      DEBIAN_RELEASE=$OPTARG
      ;;
    b)
      BOARD=$OPTARG
      ;;
    a)
      PACKAGES=$OPTARG
      ;;
    n)
      DEB_HOSTNAME=$OPTARG
      ;;
    t)
      TARGET_DIR=$OPTARG
      ;;
    i)
      INSTALL_KERNEL=$OPTARG
      ;;
    y)
      INSTALL_YUNOHOST=yes
      ;;
    c)
      CROSS=yes
      ;;
    p)
      APTCACHER=yes
      ;;
    \?)
      show_usage
      ;;
  esac
done

source ${REP}/config_board.sh

rm -rf $TARGET_DIR && mkdir -p $TARGET_DIR

chroot_deb (){
  LC_ALL=C LANGUAGE=C LANG=C chroot $1 /bin/bash -c "$2"
}

if [ ${CROSS} ] ; then
  # Debootstrap
  mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
  bash ${REP}/script/binfmt-misc-arm.sh unregister
  bash ${REP}/script/binfmt-misc-arm.sh 
  debootstrap --arch=armhf --foreign $DEBIAN_RELEASE $TARGET_DIR
  cp /usr/bin/qemu-arm-static $TARGET_DIR/usr/bin/
  cp /etc/resolv.conf $TARGET_DIR/etc
  chroot_deb $TARGET_DIR '/debootstrap/debootstrap --second-stage'
elif [ ${APTCACHER} ] ; then
 debootstrap $DEBIAN_RELEASE $TARGET_DIR http://localhost:3142/ftp.fr.debian.org/debian/
else
 debootstrap $DEBIAN_RELEASE $TARGET_DIR
fi

# mount proc, sys and dev
mount -t proc chproc $TARGET_DIR/proc
mount -t sysfs chsys $TARGET_DIR/sys
mount -t devtmpfs chdev $TARGET_DIR/dev || mount --bind /dev $TARGET_DIR/dev
mount -t devpts chpts $TARGET_DIR/dev/pts || mount --bind /dev/pts $TARGET_DIR/dev/pts

# Configure debian apt repository
cat <<EOT > $TARGET_DIR/etc/apt/sources.list
deb http://ftp.fr.debian.org/debian $DEBIAN_RELEASE main contrib non-free
deb http://security.debian.org/ $DEBIAN_RELEASE/updates main contrib non-free
EOT
cat <<EOT > $TARGET_DIR/etc/apt/apt.conf.d/71-no-recommends
APT::Install-Suggests "0";
EOT

if [ ${APTCACHER} ] ; then
 cat <<EOT > $TARGET_DIR/etc/apt/apt.conf.d/01proxy
Acquire::http::Proxy "http://localhost:3142";
EOT
fi

chroot_deb $TARGET_DIR 'apt-get update'

# Add ssh server and ntp client
chroot_deb $TARGET_DIR "apt-get install -y --force-yes openssh-server ntp parted locales $PACKAGES"

# Use dhcp on boot
cat <<EOT > $TARGET_DIR/etc/network/interfaces
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
EOT

# Debootstrap optimisations from igorpecovnik
# change default I/O scheduler, noop for flash media, deadline for SSD, cfq for mechanical drive
cat <<EOT >> $TARGET_DIR/etc/sysfs.conf
block/mmcblk0/queue/scheduler = noop
#block/sda/queue/scheduler = cfq
EOT

# flash media tunning
if [ -f "$TARGET_DIR/etc/default/tmpfs" ]; then
  sed -e 's/#RAMTMP=no/RAMTMP=yes/g' -i $TARGET_DIR/etc/default/tmpfs
  sed -e 's/#RUN_SIZE=10%/RUN_SIZE=128M/g' -i $TARGET_DIR/etc/default/tmpfs
  sed -e 's/#LOCK_SIZE=/LOCK_SIZE=/g' -i $TARGET_DIR/etc/default/tmpfs
  sed -e 's/#SHM_SIZE=/SHM_SIZE=128M/g' -i $TARGET_DIR/etc/default/tmpfs
  sed -e 's/#TMP_SIZE=/TMP_SIZE=1G/g' -i $TARGET_DIR/etc/default/tmpfs
fi

# Generate locales
sed -i "s/^# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/" $TARGET_DIR/etc/locale.gen
sed -i "s/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" $TARGET_DIR/etc/locale.gen
chroot_deb $TARGET_DIR "locale-gen en_US.UTF-8"

# Update timezone
echo 'Europe/Paris' > $TARGET_DIR/etc/timezone
chroot_deb $TARGET_DIR "dpkg-reconfigure -f noninteractive tzdata"

# Configure tty
echo T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt100 >> $TARGET_DIR/etc/inittab

# Good right on some directories
chroot_deb $TARGET_DIR 'chmod 1777 /tmp/'
chroot_deb $TARGET_DIR 'chgrp mail /var/mail/'
chroot_deb $TARGET_DIR 'chmod g+w /var/mail/'
chroot_deb $TARGET_DIR 'chmod g+s /var/mail/'

# Set hostname
echo $DEB_HOSTNAME > $TARGET_DIR/etc/hostname

# Add firstrun and secondrun init script
install -m 755 -o root -g root ${REP}/script/secondrun $TARGET_DIR/etc/init.d/
install -m 755 -o root -g root ${REP}/script/firstrun $TARGET_DIR/etc/init.d/
chroot_deb $TARGET_DIR "insserv firstrun >> /dev/null"

if [ $INSTALL_KERNEL ] ; then
  cp ${INSTALL_KERNEL}/*.deb $TARGET_DIR/tmp/
  chroot_deb $TARGET_DIR 'dpkg -i /tmp/*.deb'
  rm $TARGET_DIR/tmp/*
  cp ${INSTALL_KERNEL}/boot.scr $TARGET_DIR/boot/
  chroot_deb $TARGET_DIR "ln -s /boot/dtb/$DTB /boot/board.dtb"
fi

if [ $INSTALL_YUNOHOST ] ; then
  chroot_deb $TARGET_DIR "apt-get install -y --force-yes git"
  chroot_deb $TARGET_DIR "git clone https://github.com/YunoHost/install_script /tmp/install_script"
  chroot_deb $TARGET_DIR "cd /tmp/install_script && ./autoinstall_yunohostv2 || exit 0"
fi

# Add 'olinux' for root password and force to change it at first login
chroot_deb $TARGET_DIR '(echo olinux;echo olinux;) | passwd root'
chroot_deb $TARGET_DIR 'chage -d 0 root'

# Remove useless files
chroot_deb $TARGET_DIR 'apt-get clean'
rm $TARGET_DIR/etc/resolv.conf

if [ ${CROSS} ] ; then
  rm $TARGET_DIR/usr/bin/qemu-arm-static
fi

if [ ${APTCACHER} ] ; then
  rm $TARGET_DIR/etc/apt/apt.conf.d/01proxy 
fi

# Umount proc, sys, and dev 
umount -l $TARGET_DIR/dev/pts
umount -l $TARGET_DIR/dev
umount -l $TARGET_DIR/proc
umount -l $TARGET_DIR/sys
