#!/bin/dash

set +e

_COUNT=16

if [ -z "$1" ]; then
    echo "Usage: $0 [count]"
    echo "Example:"
    echo "  $0 16"
    exit 1
fi

COUNT="${1:-$_COUNT}"

if ! command -v swapon >/dev/null 2>&1; then
    echo "Installing swap utilities..."
    sudo apt-get update && sudo apt-get install -y util-linux
fi

if [ -f /swapfile ]; then
    echo "Removing old swap file..."
    sudo swapoff /swapfile
    sudo sh -c "rm -f /swapfile"
fi

echo "Creating new swap file with count=$COUNT..."
sleep 2
sudo touch /swapfile && sudo chmod 0600 /swapfile
sudo dd if=/dev/zero of=/swapfile bs=256M count="$COUNT" && sudo mkswap /swapfile && sudo swapon /swapfile

if ! grep -q "/swapfile swap" /etc/fstab; then
    echo "Adding swap to fstab..."
    echo "/swapfile swap swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

echo "Swap setup complete."