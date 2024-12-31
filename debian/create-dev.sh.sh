#!/bin/dash

apt-get update && apt-get install tmux -y

apt-get dist-upgrade -y
apt-get install sudo net-tools curl zsh locales htop git git-lfs openssl bzip2 gnupg2 dnsutils proxychains4 -y

git config --global http.sslVerify false
git config --global http.postBuffer 1048576000






