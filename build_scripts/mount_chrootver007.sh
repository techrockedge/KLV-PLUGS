#!/bin/sh
# mount_chroot.sh
# Revision 0.0.7 with udev support. Date: 01 July 2019
# wiak 23 May 2019+; Licence MIT (aka X11 license)

# This script is provided purely as a convenience so you don't have to
# keep entering the following commands to chroot into firstrib_rootfs

# mount a directory to share between host system and firstrib_rootfs system.
# WARNING! I've commented this out because can be dangerous, though okay if
#   you know what your doing (I zapped my main OS because I used rm -rf whilst mounted...)
# Example (may need modified, or commented out, depending on set up of your system and
# what dir you want to share):
# mkdir -p firstrib_rootfs/mnt/home
# mount --bind /mnt/home firstrib_rootfs/mnt/home

# bind mount host virtual filesystes required for chroot into firstrib_rootfs to work on host system
mkdir -p firstrib_rootfs/run/udev
mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts && mount --bind /tmp firstrib_rootfs/tmp && mount --bind /run/udev firstrib_rootfs/run/udev && cp /etc/resolv.conf firstrib_rootfs/etc/resolv.conf 

# chroot into firstrib rootfs and execute a /bin/sh process from that root filesystem
chroot firstrib_rootfs sh

# When finished working in the above chroot you need to enter exit in the chroot shell
# and then clean up the above mounts.
# As a convenience you can run the provided umount_chroot.sh script that contains
# the commands to clean up (umount) the bind mounts that were used.
