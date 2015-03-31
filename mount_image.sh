#!/bin/sh
#$1 --> nome da nova imagem

cp original_img.img $1.img
mkdir /mnt/$1
mount -t auto -o loop,offset=$((2048*512)) $1.img /mnt/$1/
mount -o bind /proc /mnt/$1/proc
mount -o bind /dev /mnt/$1/dev
mount -o bind /dev/pts /mnt/$1/dev/pts
mount -o bind /sys /mnt/$1/sys
cp /etc/resolv.conf /mnt/$1/etc/resolv.conf
