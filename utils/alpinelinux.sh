#!/bin/dash

_OS=alpine
_ARC=$(dpkg --print-architecture)
_MIRROR=http://images.linuxcontainers.org
_FILTERED_INDEX=$(curl -fsSL "${_MIRROR}/meta/1.0/index-system" | grep -v edge)
_INDEX=$(echo "$_FILTERED_INDEX" | awk -F';' -v os="$_OS" -v arch="$_ARC" '$1==os && $3==arch {print $NF}' | tail -1)
_TARGET="${_MIRROR}/${_INDEX}rootfs.tar.xz"

XUSER=m0nius
HOST=computing-alpine
PEM="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUG8QsUdArpYbyQPgXIYISf6G2q9t6s+qxP5K8Vafc6"
BOOT_LIB="/usr/share/syslinux"

ROOT=$(findmnt -no SOURCE /)
ROOT_DEV="/dev/$(lsblk -ndo pkname "$ROOT")"
ROOTFS_MNT=/mnt.$_ARC

sudo mkdir -p "$ROOTFS_MNT"/boot/syslinux
curl -fsSL "$_TARGET" | sudo tar -C "$ROOTFS_MNT" -xJ
sudo cp -a /boot/*-"$(uname -r)" "$ROOTFS_MNT"/boot

cat <<EOF | sudo tee "$ROOTFS_MNT"/boot/syslinux/syslinux.cfg
DEFAULT syslinux
PROMPT 0
TIMEOUT 50

LABEL syslinux
    MENU LABEL Boot in Syslinux
    LINUX ../vmlinuz-$(uname -r)
    APPEND root=$ROOT net.ifnames=0 rw
    INITRD ../initrd.img-$(uname -r)
EOF

cat <<EOF | sudo tee "$ROOTFS_MNT"/etc/fstab
$ROOT / ext4 rw,discard,errors=remount-ro 0 1
EOF

IFACE=$(ip route get 8.8.8.8 | sed -n 's/.*dev \([^\ ]*\).*/\1/p' | head -n 1)
_IPV4=$(ip addr show dev "$IFACE" | awk '/inet /{print $2}' | cut -d' ' -f2)
_IPv6=$(ip addr show dev "$IFACE" | awk '/inet6 /{print $2}' | cut -d' ' -f2)
GATEWAY=$(ip route show default | awk '/default/ {print $3}')

cat <<EOF | sudo tee "$ROOTFS_MNT"/etc/network/interfaces
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $_IPV4
    gateway $GATEWAY
EOF

cat <<EOF | sudo tee "$ROOTFS_MNT"/etc/resolv.conf
nameserver 1.1.1.1
EOF

find / \( ! -path '/dev/*' -and ! -path '/proc/*' -and ! -path '/sys/*' -and ! -path '/selinux/*' -and ! -path "$ROOTFS_MNT/*" \) -delete 2>/dev/null || true

"$ROOTFS_MNT/lib/ld-musl-x86_64.so.1" "$ROOTFS_MNT/bin/busybox" cp -a "$ROOTFS_MNT"/* / && rm -rf "$ROOTFS_MNT"

apk update
setup-hostname -n $HOST
apk add openrc openssh alpine-base dhcpcd curl syslinux util-linux sgdisk sudo bash
rc-update -q add devfs sysinit
rc-update -q add dmesg sysinit
rc-update -q add mdev sysinit
rc-update -q add hwdrivers sysinit

rc-update -q add hwclock boot
rc-update -q add modules boot
rc-update -q add sysctl boot
rc-update -q add hostname boot
rc-update -q add bootmisc boot
rc-update -q add syslog boot
rc-update -q add networking boot
rc-update -q add dhcpcd boot

rc-update -q add mount-ro shutdown
rc-update -q add killprocs shutdown
rc-update -q add savecache shutdown

rc-update -q add acpid default
rc-update -q add crond default
rc-update -q add sshd default

ssh-keygen -A
rc-service sshd restart

adduser --disabled-password --gecos "" $XUSER sudo && echo "$XUSER:$HOST" | chpasswd
mkdir -p /home/$XUSER/.ssh && echo "$PEM" >> /home/$XUSER/.ssh/authorized_keys
{
    echo "$PEM"
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMR2RbF/7BQzJB3DfiMSsQR3aKDXDoiLQWcjXvAAqnIp"
} >> /home/$XUSER/.ssh/authorized_keys
chmod 600 /home/$XUSER/.ssh/authorized_keys && chown -R "$XUSER:root" /home/$XUSER/.ssh
echo "$XUSER ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers.d/$XUSER

extlinux --install /boot/syslinux
sgdisk "$ROOT_DEV" --attributes=1:set:2
dd bs=440 count=1 conv=notrunc if="$BOOT_LIB"/gptmbr.bin of="$ROOT_DEV"

sync; reboot -f