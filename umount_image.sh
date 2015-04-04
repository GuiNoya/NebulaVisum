#!/bin/sh
#$1 --> image name

umount /mnt/$1/sys
umount /mnt/$1/dev/pts
umount /mnt/$1/dev
umount /mnt/$1/proc
umount /mnt/$1/
rmdir /mnt/$1/
