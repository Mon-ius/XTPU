#!/bin/dash

if swapon --show | grep -q "/swapfile"; then
    sudo swapoff /swapfile
fi

if [ -f /swapfile ]; then
    sudo rm -f /swapfile
fi

sudo touch /swapfile && sudo chmod 0600 /swapfile
sudo dd if=/dev/zero of=/swapfile bs=256M count=16 && sudo mkswap /swapfile && sudo swapon /swapfile

if ! grep -q "/swapfile swap" /etc/fstab; then
    echo "/swapfile swap swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
fi