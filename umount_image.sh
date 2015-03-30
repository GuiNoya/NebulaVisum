#!/bin/sh
#$1 --> nome da imagem

umount /mnt/$1/sys
umount /dev/pts /mnt/$1/dev/pts
umount /dev /mnt/$1/dev
umount /proc /mnt/$1/proc
umount /mnt/$1/
