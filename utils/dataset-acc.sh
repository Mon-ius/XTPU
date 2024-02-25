#!/bin/bash

sudo apt-get -qq update && sudo apt-get -qq dist-upgrade \
    && sudo apt-get -qq install curl net-tools tmux rclone \
    && sudo apt-get -qq autoremove --purge && sudo apt-get clean

l_name='mount'
l_type='personal'
l_drive=''
l_token=''

r_name='dataset'
r_type='business'
r_drive=''
r_token=''


rclone config create "$l_name" onedrive config_refresh_token false token "$l_token" drive_id "$l_drive" drive_type "$l_type" 
rclone config create "$r_name" onedrive config_refresh_token false token "$r_token" drive_id "$r_drive" drive_type "$r_type"

rclone sync -P "$l_name":/dataset "$r_name":/dataset --transfers 8 --fast-list --progress --tpslimit 48 --drive-chunk-size 512M --max-transfer 2000G --multi-thread-streams 24 --onedrive-chunk-size 128000k --sharefile-chunk-size 512M

cat << EOF | sudo tee /etc/systemd/system/rc_mount
[Unit]
Description=Onedrive (rclone)
RequiresMountsFor=/DATA
After=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount $r_name:/dataset /DATA \
        --poll-interval 15s \
        --umask 002 \
        --user-agent randomappname101 \
        --allow-other \
        --max-transfer 750G \
        --cache-dir=/cache \
        --dir-cache-time 1000h \
        --vfs-cache-mode full \
        --vfs-cache-max-size 500G \
        --vfs-cache-max-age 336h \
        --rc \
        --rc-addr :5572 \
        --rc-no-auth \
        --log-level NOTICE \
        --log-file /opt/rclone/logs/rclone.log \
        --bwlimit-file 16M

ExecStop=/bin/fusermount -u /DATA
Restart=always
RestartSec=10
User=container
Group=container

[Install]
WantedBy=default.target
EOF

sudo systemctl enable rc_mount
sudo systemctl start rc_mount