#!/bin/dash

set +e

ARGO="https://pkg.cloudflare.com/cloudflare-main.gpg"
VER=$(lsb_release -cs)
ARCH=$(dpkg --print-architecture)

curl -fsSL "$ARGO" | sudo gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/argo.gpg
echo "deb [arch=$ARCH] https://pkg.cloudflare.com/cloudflared any main" | sudo tee /etc/apt/sources.list.d/argo.list
sudo apt-get update && sudo apt-get install cloudflared