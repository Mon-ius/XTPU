#!/bin/dash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

RUSER=$1
sudo adduser --disabled-password --disabled-login --gecos "" "$RUSER"
sudo mkdir -p "/home/$RUSER/.ssh"
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYDGKmE+0M4PcMH/kTupjmcf/Ic9VbvXKD7fPHNVdem' | sudo tee "/home/$RUSER/.ssh/authorized_keys"
sudo chown -R "$RUSER:$RUSER" "/home/$RUSER/.ssh"