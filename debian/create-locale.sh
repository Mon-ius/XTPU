#!/bin/dash

export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y locales
sudo sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

sudo tee /etc/default/locale > /dev/null << 'EOF'
LANG="en_US.UTF-8"
LANGUAGE="en_US.UTF-8"
LC_NUMERIC="en_US.UTF-8"
LC_TIME="en_US.UTF-8"
LC_COLLATE="en_US.UTF-8"
LC_MONETARY="en_US.UTF-8"
LC_PAPER="en_US.UTF-8"
LC_NAME="en_US.UTF-8"
LC_ADDRESS="en_US.UTF-8"
LC_TELEPHONE="en_US.UTF-8"
LC_MEASUREMENT="en_US.UTF-8"
LC_IDENTIFICATION="en_US.UTF-8"
EOF

sudo dpkg-reconfigure --frontend=noninteractive locales

# sudo tee /etc/default/locale > /dev/null << 'EOF'
# LC_ALL="en_US.UTF-8"
# EOF