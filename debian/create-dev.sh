#!/bin/dash

export DEBIAN_FRONTEND=noninteractive

apt-get -qq update
apt-get -qq -o 'Dpkg::Options::=--force-confdef' -o 'Dpkg::Options::=--force-confmiss' dist-upgrade -y
do-release-upgrade -f DistUpgradeViewNonInteractive

apt-get -qq install -o Dpkg::Options::="--force-confold" -y vim curl tmux sudo

apt-get -qq dist-upgrade -y
apt-get -qq install -o Dpkg::Options::="--force-confold" -y \
    sudo net-tools zsh locales htop git git-lfs openssl gnupg2 dnsutils tree wget bzip2 unzip proxychains4

git config --global http.sslVerify false
git config --global http.postBuffer 1048576000