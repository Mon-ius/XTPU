#!/bin/dash

_R=3.19
_ARC=$(arch)
_REL="${1:-$_R}"
_TARGET="https://dl-cdn.alpinelinux.org/alpine/v${_REL}/releases/${_ARC}/alpine-minirootfs-${_REL}.1-${_ARC}.tar.gz"

XUSER=m0nius
HOST=computing-alpine
TEST_PEM="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUG8QsUdArpYbyQPgXIYISf6G2q9t6s+qxP5K8Vafc6"
TEST_PEM_X="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKEJeeEzrSnWvMXyPmW8M0L09V/vqhVKAadnE9G62hHC"
FEATURES="ata base ide scsi usb virtio ext4"
MODULES="sd-mod,usb-storage,ext4"

ROOT=$(findmnt -no SOURCE /)
ROOT_DEV="/dev/$(lsblk -ndo pkname "$ROOT")"
ROOTFS_MNT=/mnt.$_ARC
BOOT_PATH=/boot
BOOT_LIB="/usr/share/syslinux"

sudo mkdir -p "$ROOTFS_MNT"/"$BOOT_PATH"
curl -fsSL "$_TARGET" | sudo tar -C "$ROOTFS_MNT" -xz

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

cat <<EOF | tee "$ROOTFS_MNT"/etc/fstab
$ROOT / ext4 rw,discard,errors=remount-ro 0 1
EOF

find / \( ! -path '/dev/*' -and ! -path '/proc/*' -and ! -path '/sys/*' -and ! -path '/selinux/*' -and ! -path "$ROOTFS_MNT/*" \) -delete 2>/dev/null || true

"$ROOTFS_MNT/lib/ld-musl-x86_64.so.1" "$ROOTFS_MNT/bin/busybox" cp -a "$ROOTFS_MNT"/* /
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
rm -rf "$ROOTFS_MNT"

apk update
apk add openrc openssh alpine-base curl syslinux util-linux sgdisk sudo bash
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

rc-update -q add mount-ro shutdown
rc-update -q add killprocs shutdown
rc-update -q add savecache shutdown

rc-update -q add acpid default
rc-update -q add crond default
rc-update -q add sshd default

ssh-keygen -A
rc-service sshd restart

echo features=\""$FEATURES"\" > /etc/mkinitfs/mkinitfs.conf

cat << EOF | tee /etc/update-extlinux.conf
overwrite=1
vesa_menu=0
default_kernel_opts="quiet"
modules=$MODULES
root=$ROOT
verbose=0
hidden=1
timeout=1
default=grsec
serial_port=
serial_baud=115200
password=''
EOF

apk add linux-virt
setup-hostname -n $HOST
mv /boot/extlinux.conf $BOOT_PATH/syslinux.cfg

grep -q '^[[:space:]]*eth' /proc/net/dev && _policy=" net.ifnames=0"
sed -i "s;\\(^[[:space:]]*APPEND.*\\)root=[^[:space:]]*;\\1root=$ROOT$_policy;" $BOOT_PATH/syslinux.cfg

adduser --disabled-password --gecos "" $XUSER sudo && echo "$XUSER:$HOST" | chpasswd
mkdir -p /home/$XUSER/.ssh && echo "$PEM" >> /home/$XUSER/.ssh/authorized_keys
{
    echo "$TEST_PEM"
    echo "$TEST_PEM_X"
} >> /home/$XUSER/.ssh/authorized_keys
chmod 600 /home/$XUSER/.ssh/authorized_keys && chown -R "$XUSER:root" /home/$XUSER/.ssh
echo "$XUSER ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers.d/$XUSER

extlinux --install $BOOT_PATH
sgdisk "$ROOT_DEV" --attributes=1:set:2
dd bs=440 count=1 conv=notrunc if="$BOOT_LIB"/gptmbr.bin of="$ROOT_DEV"

sleep 600
sync; reboot -f