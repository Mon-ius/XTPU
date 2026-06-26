#!/bin/dash

export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y util-linux

COUNT=8

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