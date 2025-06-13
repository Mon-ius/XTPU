#!/bin/dash

if ! command -v swapon >/dev/null 2>&1; then
    echo "Installing swap utilities..."
    sudo apt-get update && sudo apt-get install -y util-linux
fi

if command -v swapon >/dev/null 2>&1 && swapon --show | grep -q "/swapfile"; then
    echo "Deactivating existing swap file..."
    sudo swapoff /swapfile
    sleep 3
fi

if [ -f /swapfile ]; then
    echo "Checking file attributes..."
    if command -v lsattr >/dev/null 2>&1; then
        sudo chattr -i /swapfile 2>/dev/null || true
    fi
    
    echo "Ensuring file is not in use..."
    sudo sync
    sleep 2
    
    echo "Removing old swap file..."
    sudo rm -f /swapfile || {
        echo "Failed to remove swap file, trying alternative method..."
        sudo mv /swapfile /swapfile.old 2>/dev/null || true
        sudo rm -f /swapfile.old 2>/dev/null || true
    }
fi

if [ -f /swapfile ]; then
    echo "Error: Unable to remove existing swap file"
    exit 1
fi

echo "Creating new swap file..."
sudo fallocate -l 4G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=256M count=16 status=progress
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

if ! grep -q "/swapfile swap" /etc/fstab; then
    echo "Adding swap to fstab..."
    echo "/swapfile swap swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

echo "Verifying swap status..."
free -h
echo "Swap setup complete."