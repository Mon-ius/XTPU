#!/bin/dash

export DEBIAN_FRONTEND=noninteractive
DOCKER="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg"
VER=$(lsb_release -cs)
ARCH=$(dpkg --print-architecture)

curl -fsSL "$DOCKER" | sudo -E gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
echo "deb [arch=$ARCH] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian $VER stable" | sudo -E tee /etc/apt/sources.list.d/docker.list

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y docker-ce docker-compose-plugin

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