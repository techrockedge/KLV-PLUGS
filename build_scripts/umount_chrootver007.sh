#!/bin/sh
# umount_chroot.sh
# Revision 0.0.7 with udev support. Date: 01 July 2019
# wiak 23 May 2019+; Licence MIT (aka X11 license)

# This script is provided purely as a convenience so you don't have to
# keep entering the following commands to cleanup the firstrib_rootfs chroot:

# Clean up the bind mounts that were used for the chroot:
umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev && umount -l firstrib_rootfs/tmp && umount -l firstrib_rootfs/run/udev

# umount directory shared between host system and firstrib_rootfs system.
# Example (may need modified, or commented out, depending on set up of your system and
# what dir you shared):
# Commented out since not used for now: see WARNING note in mount_chroot.sh
# umount firstrib_rootfs/mnt/home
