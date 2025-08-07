#!/bin/dash

export DEBIAN_FRONTEND=noninteractive
DOCKER="https://download.docker.com/linux/debian/gpg"

VER=$(lsb_release -cs)
ARCH=$(dpkg --print-architecture)

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y gnupg2

curl -fsSL "$DOCKER" | sudo -E gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
echo "deb [arch=$ARCH] https://download.docker.com/linux/debian $VER stable" | sudo -E tee /etc/apt/sources.list.d/docker.list

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y docker-ce docker-compose-plugin docker-compose

sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
    "ipv6": true,
    "fixed-cidr-v6": "fd00::/64"
}
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now docker
sudo systemctl restart docker

sudo /usr/sbin/groupadd docker
sudo /usr/sbin/usermod -aG docker "${USER}"
sudo chmod 666 /var/run/docker.sock
sudo chown root:docker /var/run/docker.sock