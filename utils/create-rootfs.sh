#!/bin/dash

_OS=debian
_ARC=$(dpkg --print-architecture)
_XUSER=m0nius
_PASSWD="QTVGMEZ5Nwo="
_PEM="c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUVpN3JGb01qaXVjbVU0ZzRwZ1RpMXJUWXNxZ1ZpNXdPczhLekRjMFVaU0UK"
_HOST=dev-machine
_PKG="vim curl tmux openssh-server ntpdate sudo ifupdown net-tools udev iputils-ping wget dosfstools unzip binutils libatomic1 zsh htop git git-lfs openssl gnupg2 tree bzip2 proxychains4 kmod openssh-server extlinux efibootmgr"
MNT_ROOT=/mnt/debinst
MNT_BOOT=/mnt/boot

IFACE=$(ip route get 8.8.8.8 | sed -n 's/.*dev \([^\ ]*\).*/\1/p' | head -n 1)
_IPV4=$(ip addr show dev "$IFACE" | awk '/inet /{print $2}' | cut -d' ' -f2)
_IPv6=$(ip addr show dev "$IFACE" | awk '/inet6 /{print $2}' | cut -d' ' -f2)
GATEWAY=$(ip route show default | awk '/default/ {print $3}')

sudo mkdir -p "$MNT_ROOT"
sudo mkdir -p "$MNT_BOOT"

sudo apt-get -qq update && sudo apt-get -qq dist-upgrade
sudo apt-get -qq install debootstrap qemu-user-static binfmt-support 

sudo debootstrap --arch="$_ARC" bullseye "$MNT_ROOT" http://ftp.hk.debian.org/debian

sudo cp -fL /etc/fstab "$MNT_ROOT/etc/fstab"

sudo mount -t proc /proc -o nosuid,noexec,nodev "$MNT_ROOT/proc"
sudo mount -t sysfs /sys -o nosuid,noexec,nodev,ro "$MNT_ROOT/sys"
sudo mount -t devtmpfs -o mode=0755,nosuid udev "$MNT_ROOT/dev"
sudo mount --bind /dev/pts "$MNT_ROOT/dev/pts"

TERM=xterm-color LANG=C.UTF-8 sudo chroot $MNT_ROOT /bin/bash -x << CHROOT
echo "127.0.0.1 $_HOST" | tee -a /etc/hosts
echo "$_HOST" | tee -a /etc/hostname

cat <<EOF | tee /etc/network/interfaces
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet static
    address $_IPV4
    gateway $GATEWAY
EOF

cat <<EOF | tee /etc/resolv.conf
nameserver 1.1.1.1
EOF

cat <<EOF | tee /etc/apt/sources.list
deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb http://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

cat <<EOF | tee -a /etc/security/limits.conf
root soft nofile 100000
root hard nofile 100000
*       hard    nofile  100000
*       soft    nofile  100000
EOF

cat <<EOF | tee -a /etc/modules
tun
loop
ip_tables
tcp_bbr
EOF

cat <<EOF | tee /etc/sysctl.d/bbr.conf
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.wmem_max = 26214400
net.core.rmem_max = 26214400
fs.file-max = 65535
EOF

cat <<EOF | tee /etc/sysctl.d/99-allow-ping.conf
net.ipv4.ping_group_range=1001 10001
EOF

apt-get -qq update && apt-get -qq install locales dialog
echo "en_US.UTF-8 UTF-8" | tee /etc/locale.gen > /dev/null && locale-gen
echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
dpkg-reconfigure -f noninteractive locales
apt-get -qq install $_PKG
apt-get -y install linux-image-6.1.0-27-amd64

echo "$_XUSER ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers.d/$_XUSER
adduser --disabled-password --gecos "" $_XUSER
echo "$_XUSER:$(echo $_PASSWD | base64 -d)" | chpasswd

su $_XUSER -c "
    mkdir -p ~/.ssh &&
    touch ~/.ssh/authorized_keys &&
    echo $_PEM | base64 -d >> ~/.ssh/authorized_keys &&
    git clone --depth=1 https://github.com/AUTOM77/dotfile /tmp/dotfile
    find /tmp/dotfile/.zsh/ -mindepth 1 -maxdepth 1 -exec mv {} "/home/$_XUSER" \;
"
chsh -s /usr/bin/zsh "${_XUSER}"

cat <<'EOF' | tee /etc/ssh/sshd_config
Include /etc/ssh/sshd_config.d/*.conf
KbdInteractiveAuthentication no
UsePAM yes
PrintMotd no
AcceptEnv LANG LC_*

ChallengeResponseAuthentication no
PasswordAuthentication no
PermitRootLogin no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
X11Forwarding yes
GatewayPorts yes
ClientAliveInterval 60
ClientAliveCountMax 3
EOF

apt clean
rm -rf vmlinuz.old
exit
CHROOT

sudo umount -l "$MNT_ROOT/dev/pts"
sudo umount -l "$MNT_ROOT/dev"
sudo umount -l "$MNT_ROOT/sys"
sudo umount -l "$MNT_ROOT/proc"

cd $MNT_ROOT && sudo tar -cJvf debian-12-rootfs-amd64.tar.xz ./*