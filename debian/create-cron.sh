#!/bin/dash

sudo apt-get -qq update && sudo apt-get -qq install cron
sudo timedatectl set-timezone UTC
sudo tee -a /etc/cron.d/autoreboot.cron > /dev/null <<EOT
0 14 * * * reboot
EOT