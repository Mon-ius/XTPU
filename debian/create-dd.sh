#!/bin/dash

set +e

sudo -i
sudo apt update && sudo apt dist-upgrade -y && sudo apt install lsof

sudo snap remove --purge  oracle-cloud-agent && sudo snap remove --purge core18
sudo apt purge -y $(dpkg-query -Wf '${Package}\n' | grep header)  $(apt list --installed | grep -oP "^linux.*\d\d\d\d-oracle" | grep -v "$(uname -r)") linux-modules-extra-$(uname -r) lxc* lxd* vim* && sudo apt -y autoremove && sudo apt -y autoclean && sudo apt -y clean  
sudo rm -rf /var/log/* /var/lib/apt/lists/*

swapoff -a
rm -f /swapfile /swap.img

echo "Disk usage before copying to tmpfs:"
df -h / | grep -v tmpfs
du -sh --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run --exclude=/mnt /* 2>/dev/null | sort -h

cd /
mount -t tmpfs -o size=2000m tmpfs mnt
tar --one-file-system --exclude='./swapfile' --exclude='./swap.img' --exclude='./tmp/*' --exclude='./var/tmp/*' --exclude='./var/cache/*' --exclude='./mnt/*' --exclude='./lost+found' -c . | tar -C /mnt -x
mount --make-private -o remount,rw /
mount --move dev mnt/dev
mount --move proc mnt/proc
mount --move run mnt/run
mount --move sys mnt/sys
sed -i '/^[^#]/d;' mnt/etc/fstab
echo 'tmpfs / tmpfs defaults 0 0' >> mnt/etc/fstab
cd mnt
mkdir old_root
mount --make-private /
unshare -m
pivot_root . old_root
/usr/sbin/sshd -D -p 1022 &

iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 1022 -j ACCEPT

pkill agetty
pkill dbus-daemon
pkill atd
pkill iscsid
pkill rpcbind
pkill unattended-upgrades
kill 1 

umount -l /dev/sda1

df -h 
lsblk 
curl -L https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-arm64.tar.xz | tar -OJxvf - disk.raw | dd of=/dev/sda bs=1M

sync

reboot