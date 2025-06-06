#!/bin/dash

set -e

SOURCES_FILE="/etc/apt/sources.list"
BACKUP_FILE="/etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)"

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

cp "$SOURCES_FILE" "$BACKUP_FILE"
echo "Backup created at: $BACKUP_FILE"

sed -i 's/^deb/#deb/g' "$SOURCES_FILE"
sed -i 's/^deb-src/#deb-src/g' "$SOURCES_FILE"

cat >> "$SOURCES_FILE" << EOF

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

echo "THU mirror sources for Debian Bookworm added successfully"

apt update

echo "APT sources updated successfully"