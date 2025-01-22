#!/bin/dash

apt-get update && apt-get install vim curl tmux -y

apt-get dist-upgrade -y
apt-get install sudo net-tools zsh locales htop git git-lfs openssl gnupg2 dnsutils tree wget bzip2 unzip proxychains4 -y

git config --global http.sslVerify false
git config --global http.postBuffer 1048576000