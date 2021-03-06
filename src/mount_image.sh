#!/bin/sh
#$1 --> new image name

#cp /etc/NebulaVisum/images/original_img.img /etc/NebulaVisum/images/$1.img

mkdir -p /mnt/$1
mount -t auto -o loop,offset=$((2048*512)) /etc/NebulaVisum/images/$1.img /mnt/$1/
mount -o bind /proc /mnt/$1/proc
mount -o bind /dev /mnt/$1/dev
mount -o bind /dev/pts /mnt/$1/dev/pts
mount -o bind /sys /mnt/$1/sys
cp /etc/resolv.conf /mnt/$1/etc/resolv.conf
mkdir -p /mnt/$1/etc/NebulaVisum
