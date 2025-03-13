#!/bin/dash

export DEBIAN_FRONTEND=noninteractive

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y gnupg2 curl

DART="https://dl-ssl.google.com/linux/linux_signing_key.pub"
ARCH=$(dpkg --print-architecture)

curl -fsSL "$DART" | sudo gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/dart.gpg
echo "deb [arch=$ARCH] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" | sudo tee /etc/apt/sources.list.d/dart.list
sudo apt-get update && sudo apt-get install dart