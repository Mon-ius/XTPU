#!/bin/dash

apt-get update && apt-get install tmux -y

apt-get dist-upgrade -y
apt-get install sudo net-tools curl zsh locales htop git git-lfs openssl bzip2 gnupg2 dnsutils proxychains4 -y

git config --global http.sslVerify false
git config --global http.postBuffer 1048576000

#---

XUSER=dev
PASSWD=AAAAIJcz7vmj1j7ssxPv5F0Fy7
PUB_KEY_0='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC+VtPVQc51zZLUbAzqx/jXygcK1imNc2yoHzdzjqOUa'
PUB_KEY_1='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDWJ4UGB7emxS6NdVe7G/yy36pf63K1VrrPfAlXjuwui'
PUB_KEY_2='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM0YC4tbZ6EjzoqlyYgQo2C0SKD5bhrCKc/O9Rs/tZps'
PUB_KEY_3='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGnwFB1b3DAConi5RSjIWJZqB62CMc8tMCpuLSdMQQDq'

echo "$XUSER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/$XUSER
sudo adduser --disabled-password --gecos "" $XUSER && echo "$XUSER:$PASSWD" | sudo chpasswd

sudo su $XUSER -c "
    mkdir -p ~/.ssh &&
    touch ~/.ssh/authorized_keys &&
    echo $PUB_KEY_0 >> ~/.ssh/authorized_keys &&
    echo $PUB_KEY_1 >> ~/.ssh/authorized_keys &&
    echo $PUB_KEY_2 >> ~/.ssh/authorized_keys &&
    echo $PUB_KEY_3 >> ~/.ssh/authorized_keys &&
    git clone --depth=1 https://github.com/AUTOM77/dotfile ~/.dotfile &&
    mv ~/.dotfile/.zsh/.*  "/home/$XUSER"
    rm -rf ~/.dotfile
"
sudo chsh -s "$(which zsh)" "${XUSER}"







