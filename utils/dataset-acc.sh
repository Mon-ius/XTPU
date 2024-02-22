#!/bin/bash

sudo apt-get -qq update && sudo apt-get -qq dist-upgrade \
    && sudo apt-get -qq install curl net-tools tmux rclone \
    && sudo apt-get -qq autoremove --purge && sudo apt-get clean

_name="$1"
_id="$2"
_secret="$3"
_drive="$4"

token=$(rclone authorize "onedrive" "$_id" "$_secret" --auth-no-open-browser)

rclone config create "$_name" onedrive client_id "$_id" client_secret "$_secret" config_refresh_token false token "$token" drive_id "$_drive" drive_type business 

rclone sync -P dataset:/"$_name" /dev/shm/"$_name" --transfers 8 --fast-list --progress --tpslimit 48 --drive-chunk-size 512M --max-transfer 2000G --multi-thread-streams 24 --onedrive-chunk-size 128000k --sharefile-chunk-size 512M