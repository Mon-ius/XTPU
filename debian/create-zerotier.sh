#!/bin/dash

export DEBIAN_FRONTEND=noninteractive
ZEROTIER="https://raw.githubusercontent.com/zerotier/ZeroTierOne/master/doc/contact%40zerotier.com.gpg"
VER=$(lsb_release -cs)
ARCH=$(dpkg --print-architecture)

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y gnupg2

curl -fsSL "$ZEROTIER" | sudo -E gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/zerotier.gpg
echo "deb [arch=$ARCH] https://download.zerotier.com/debian/$VER $VER main" | sudo -E tee /etc/apt/sources.list.d/zerotier.list

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y zerotier-one