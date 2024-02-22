#!/bin/bash

sudo apt-get -qq update && sudo apt-get -qq dist-upgrade \
    && sudo apt-get -qq install curl net-tools tmux rclone \
    && sudo apt-get -qq autoremove --purge && sudo apt-get clean