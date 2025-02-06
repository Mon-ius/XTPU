#!/bin/dash

sudo apt-get -qq update && sudo apt-get -qq install cron
sudo timedatectl set-timezone UTC

echo "0 14 * * * reboot" | sudo tee -a /etc/cron.d/autoreboot.cron > /dev/null