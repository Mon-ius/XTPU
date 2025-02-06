#!/bin/dash

DOCKER="https://download.docker.com/linux/debian/gpg"
VER=$(lsb_release -cs)
ARCH=$(dpkg --print-architecture)

sudo apt-get update && sudo apt-get install gnupg2 -y
curl -fsSL "$DOCKER" | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
echo "deb [arch=$ARCH] https://download.docker.com/linux/debian $VER stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update && sudo apt-get install docker-ce docker-compose-plugin -y

sudo chmod 666 /var/run/docker.sock
sudo groupadd docker
sudo usermod -aG docker "$USER"