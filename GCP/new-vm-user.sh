#!/bin/bash

NEWBEE="m0niusplus"
NEWBEE_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJc+hizI/z7vmj1jt9HzIaADzZ7ssxPv5F0Fy7pWv6/L'

sudo adduser --disabled-password --gecos "" $NEWBEE
sudo su $NEWBEE -c "mkdir -p ~/.ssh"
sudo su $NEWBEE -c "touch ~/.ssh/authorized_keys"
sudo su $NEWBEE -c "echo $NEWBEE_KEY > ~/.ssh/authorized_keys"
sudo su $NEWBEE -c "curl -fsSL https://sh.rustup.rs | sh -s -- -y"
sudo su $NEWBEE -c ". ~/.cargo/env && rustup update nightly && rustup default nightly"
echo "$NEWBEE ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/$NEWBEE

echo "net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.wmem_max = 26214400
net.core.rmem_max = 26214400
fs.file-max = 65535" | sudo tee /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf

sudo apt-get -qq update
sudo apt-get -qq install net-tools curl gnupg2 tmux bzip2 jq git git-lfs clang
