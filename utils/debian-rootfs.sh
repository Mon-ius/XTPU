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
size=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
size=1G, type=21686148-6449-6E6F-744E-656564454649
size=2G, type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
size=, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

sudo mkfs.msdos -F 32 -n 'Boot' "$_DEV"1
sudo mkfs.ext4 "$_DEV"2
sudo mkfs.ext4 "$_DEV"3

sudo mkdir -p /boot/EFI/syslinux
sudo cp -r /usr/lib/syslinux/modules/efi64/* /boot/EFI/syslinux
sudo cp /usr/share/preloader-signed/PreLoader.efi /boot/EFI/syslinux
sudo cp /usr/share/preloader-signed/HashTool.efi /boot/EFI/syslinux
sudo cp /boot/EFI/syslinux/syslinux.efi /boot/EFI/syslinux/loader.efi

sudo efibootmgr -c -d "$_DEV" -p 1 -l \\efi\\syslinux\\syslinux.efi -L Gentoo

sudo mkdir -p "$MNT_ROOT"
sudo mkdir -p "$MNT_BOOT"
curl -fsSL "$DEBIAN" | sudo tar -C "$MNT_ROOT" -xJ
sudo tar -xpf debian-12-nocloud-amd64.tar.xz -C $MNT_ROOT
