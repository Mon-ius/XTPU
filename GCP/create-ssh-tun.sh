#!/bin/dash

XUSER=tun
sudo adduser --disabled-password --disabled-login --gecos "" $XUSER
sudo mkdir -p /home/$XUSER/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYDGKmE+0M4PcMH/kTupjmcf/Ic9VbvXKD7fPHNVdem' | sudo tee /home/$XUSER/.ssh/authorized_keys
sudo chown -R $XUSER:$XUSER /home/$XUSER/.ssh