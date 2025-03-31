#!/bin/dash

if ! command -v swapon >/dev/null 2>&1; then
    echo "Installing swap utilities..."
    sudo apt-get update && sudo apt-get install -y util-linux
fi

if command -v swapon >/dev/null 2>&1 && swapon --show | grep -q "/swapfile"; then
    echo "Deactivating existing swap file..."
    sudo swapoff /swapfile
fi

if [ -f /swapfile ]; then
    echo "Removing old swap file..."
    sudo rm -f /swapfile
fi

echo "Creating new swap file..."
sleep 2
sudo touch /swapfile && sudo chmod 0600 /swapfile
sudo dd if=/dev/zero of=/swapfile bs=256M count=16 && sudo mkswap /swapfile && sudo swapon /swapfile

if ! grep -q "/swapfile swap" /etc/fstab; then
    echo "Adding swap to fstab..."
    echo "/swapfile swap swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

echo "Swap setup complete."