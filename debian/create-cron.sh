#!/bin/dash

export DEBIAN_FRONTEND=noninteractive

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y cron

sudo timedatectl set-timezone UTC
echo "0 14 * * * reboot" | sudo tee -a /etc/cron.d/autoreboot.cron > /dev/null