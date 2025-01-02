#!/bin/dash

_OS=debian
_ARC=$(dpkg --print-architecture)
_DEV=/dev/sdb
DEBIAN="https://github.com/Mon-ius/XTPU/releases/download/v1.0.0/debian-12-rootfs-amd64.tar.xz"

ROOT=$(findmnt -no SOURCE /)
ROOT_DEV=/dev/$(lsblk -ndo pkname "$ROOT")
MNT_ROOT=/mnt/debinst
MNT_BOOT=/mnt/boot

sudo dd bs=4M status=progress if=/dev/zero of="$_DEV"

sudo sfdisk "$_DEV" <<EOF
label: gpt
size=1G, type=21686148-6449-6E6F-744E-656564454649
size=2G, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
size=, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709
EOF

sudo mkfs.msdos -F 32 -n 'Boot' /dev/sdb1

sudo mkfs.fat -F32 /dev/sdb1
sudo mkfs.ext4 /dev/sdb2
sudo mkfs.ext4 /dev/sdb3

sudo mkdir -p "$MNT_ROOT"
sudo mkdir -p "$MNT_BOOT"
curl -fsSL "$DEBIAN" | sudo tar -C "$MNT_ROOT" -xJ
sudo tar -xpf debian-12-nocloud-amd64.tar.xz -C $MNT_ROOT
