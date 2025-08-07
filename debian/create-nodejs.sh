#!/bin/dash

set +e
export DEBIAN_FRONTEND=noninteractive
NODEJS="https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
NODE_VERSION="24"

ARCH=$(dpkg --print-architecture)

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y gnupg2

curl -fsSL "$NODEJS" | sudo -E gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/node_$NODE_VERSION.gpg
echo "deb [arch=$ARCH] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" | sudo -E tee /etc/apt/sources.list.d/node_$NODE_VERSION.list

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y nodejs npm