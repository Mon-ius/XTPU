#!/bin/dash

DOCKER="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg"
VER=$(lsb_release -cs)
ARCH=$(dpkg --print-architecture)

curl -fsSL "$DOCKER" | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
echo "deb [arch=$ARCH] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian $VER stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update && sudo apt-get install docker-ce docker-compose-plugin -y

sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": [
        "https://docker.1ms.run"
    ]
}
EOF
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl restart docker

sudo chmod 666 /var/run/docker.sock
sudo groupadd docker
sudo usermod -aG docker "$USER"