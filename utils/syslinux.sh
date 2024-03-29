#!/bin/dash

sudo apt-get -qq update && sudo apt-get -qq install extlinux fdisk gdisk
sudo apt-get -qq remove grub* && sudo apt-get -qq autoremove --purge

ROOT=$(findmnt -no SOURCE /)
ROOT_DEV="/dev/$(sudo lsblk -ndo pkname "$ROOT")"
BOOT_LD="/boot/syslinux"
BOOT_LIB="/usr/lib/syslinux"

sudo mkdir -p "$BOOT_LD" && sudo rm -rf /boot/grub
cat <<EOF | sudo tee "$BOOT_LD"/syslinux.cfg
DEFAULT syslinux
PROMPT 0
TIMEOUT 50

LABEL syslinux
    MENU LABEL Boot in Syslinux
    LINUX ../vmlinuz-$(uname -r)
    APPEND root=$ROOT net.ifnames=0 rw
    INITRD ../initrd.img-$(uname -r)
EOF

cat <<EOF | sudo tee /etc/fstab
$ROOT / ext4 rw,discard,errors=remount-ro 0 1
EOF

sudo extlinux --install "$BOOT_LD" > /dev/null 2>&1
sudo sgdisk "$ROOT_DEV" --attributes=1:set:2 > /dev/null 2>&1
sudo dd bs=440 count=1 conv=notrunc if="$BOOT_LIB"/mbr/gptmbr.bin of="$ROOT_DEV"

sync; reboot -f