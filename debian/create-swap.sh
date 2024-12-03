#!/bin/dash

sudo touch /swapfile && sudo chmod 0600 /swapfile 
sudo dd if=/dev/zero of=/swapfile bs=256M count=8 && sudo mkswap /swapfile && sudo swapon /swapfile
echo "/swapfile swap swap sw 0 0" | sudo tee -a /etc/fstab