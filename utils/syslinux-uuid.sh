#!/bin/dash

sudo apt-get -qq update && sudo apt-get -qq install extlinux fdisk gdisk
sudo apt-get -qq remove grub* && sudo apt-get -qq autoremove --purge

ROOT=$(findmnt -no SOURCE /)
ROOT_DEV="/dev/$(sudo lsblk -ndo pkname "$ROOT")"
UUID=$(sudo blkid -s UUID -o value "$ROOT")
BOOT_LD="/boot/syslinux"
BOOT_LIB="/usr/lib/syslinux"

sudo mkdir -p "$BOOT_LD" && sudo rm -rf /boot/grub
cat <<EOF | sudo tee "$BOOT_LD"/syslinux.cfg
DEFAULT syslinux
PROMPT 0
TIMEOUT 50

LABEL syslinux
        MENU LABEL Boot in Syslinux
        LINUX ../vmlinuz-6.1.0-9-amd64
        APPEND root=UUID=$UUID net.ifnames=0 rw
        INITRD ../initrd.img-6.1.0-9-amd64
EOF

cp -a "$BOOT_LIB"/modules/bios/*.c32 "$BOOT_LD"
sudo extlinux --install "$BOOT_LD" > /dev/null 2>&1
sudo sgdisk "$ROOT_DEV" --attributes=1:set:2 > /dev/null 2>&1
sudo dd bs=440 count=1 conv=notrunc if="$BOOT_LIB"/mbr/gptmbr.bin of="$ROOT_DEV"

sync; reboot -f