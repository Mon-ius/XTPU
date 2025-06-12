#!/bin/dash

set -e

_HOSTNAME="DEBIAN"
HOSTNAME="${1:-$_HOSTNAME}"

echo "127.0.0.1 $HOSTNAME" | sudo tee -a /etc/hosts
sudo hostnamectl set-hostname $HOSTNAME