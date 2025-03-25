#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
CRON_JOB="0 21 * * 5 root /sbin/shutdown -r now"

if [ -f /etc/alpine-release ]; then
    doas apk add --no-cache tzdata
    doas cp /usr/share/zoneinfo/UTC /etc/localtime
    echo "UTC" | doas tee /etc/timezone
    if ! grep -F "$CRON_JOB" /etc/crontabs/root >/dev/null 2>&1; then
        echo "$CRON_JOB" | doas tee -a /etc/crontabs/root
        doas /etc/init.d/crond restart
    fi
else
    
    sudo -E apt-get -qq update
    sudo -E apt-get -qq install -y tzdata cron
    sudo ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    echo "UTC" | sudo tee /etc/timezone
    sudo dpkg-reconfigure -f noninteractive tzdata
    if ! grep -F "$CRON_JOB" /etc/crontab >/dev/null 2>&1; then
        echo "$CRON_JOB" | sudo tee -a /etc/crontab
        sudo systemctl restart cron
    fi
fi

echo "System configured to restart every Friday at 9 PM UTC"