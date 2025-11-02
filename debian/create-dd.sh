#!/bin/dash

set +e

sudo -i
sudo apt update && sudo apt dist-upgrade -y && sudo apt install lsof

sudo snap remove --purge  oracle-cloud-agent && sudo snap remove --purge core18
sudo apt purge -y "$(dpkg-query -Wf '${Package}\n' | grep header)" "$(apt list --installed | grep -oP "^linux.*\d\d\d\d-oracle" | grep -v "$(uname -r)")" "linux-modules-extra-$(uname -r)" lxc* lxd* vim* && sudo apt -y autoremove && sudo apt -y autoclean && sudo apt -y clean  
sudo rm -rf /var/log/* /var/lib/apt/lists/*

cd /
echo "Mounting tmpfs..."
mount -t tmpfs -o size=600m tmpfs mnt || { echo "Failed to mount tmpfs"; exit 1; }

echo "Copying filesystem to RAM (this will take several minutes on 1-core systems)..."
tar --one-file-system --exclude='./swapfile' --exclude='./swap.img' --exclude='./tmp/*' --exclude='./var/tmp/*' --exclude='./var/cache/*' --exclude='./var/lib/snapd/*' --exclude='./boot/*' --exclude='./mnt/*' --exclude='./lost+found' -cvpf - . 2>/dev/null | tar -C /mnt -xpf - || { echo "tar failed"; exit 1; }

echo "Filesystem copied. Size in tmpfs:"
du -sh /mnt

USED_KB=$(du -s /mnt | awk '{print $1}')
if [ "$USED_KB" -gt 600000 ]; then
    echo "ERROR: Filesystem ($USED_KB KB) exceeds tmpfs size (600MB). Aborting."
    umount /mnt
    exit 1
fi

sed -i '/^[^#]/d;' mnt/etc/fstab
echo 'tmpfs / tmpfs defaults 0 0' >> mnt/etc/fstab

cd /

mount --move /dev /mnt/dev
mount --move /proc /mnt/proc
mount --move /run /mnt/run
mount --move /sys /mnt/sys
mount --bind /mnt /mnt

umount -l /mnt/mnt 2>/dev/null || true

cd /mnt || exit 1
mkdir -p old_root run/sshd

do_install() {
    echo "Starting SSH on port 1022..."
    /usr/sbin/sshd -p 1022 &
    iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 1022 -j ACCEPT

    echo "Killing processes..."
    pkill agetty || true
    pkill dbus-daemon || true
    pkill atd || true
    pkill iscsid || true
    pkill rpcbind || true
    pkill -f unattended-upgrades || true

    echo "Unmounting old root disk..."
    umount -l /dev/sda1 2>/dev/null || true

    echo "Downloading and writing new Debian image..."
    df -h
    lsblk
    curl -L https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-arm64.tar.xz | tar -OJxvf - disk.raw | dd of=/dev/sda bs=1M status=progress

    sync
    echo "Image written successfully. Rebooting..."
    reboot
}

if pivot_root . old_root 2>/dev/null; then
    echo "pivot_root succeeded"
    do_install
else
    echo "pivot_root failed, using chroot approach"
    chroot . /bin/sh << 'CHROOT_EOF'
set -e
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev 2>/dev/null || mount --bind /dev /dev
mount -t tmpfs run /run
mkdir -p /run/sshd

echo "Starting SSH on port 1022..."
/usr/sbin/sshd -p 1022 &
iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 1022 -j ACCEPT

echo "Killing processes..."
pkill agetty || true
pkill dbus-daemon || true
pkill atd || true
pkill iscsid || true
pkill rpcbind || true
pkill -f unattended-upgrades || true

echo "Unmounting old root disk..."
umount -l /dev/sda1 2>/dev/null || true

echo "Downloading and writing new Debian image..."
df -h
lsblk
curl -L https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-arm64.tar.xz | tar -OJxvf - disk.raw | dd of=/dev/sda bs=1M status=progress

sync
echo "Image written successfully. Rebooting..."
reboot
CHROOT_EOF
fi


