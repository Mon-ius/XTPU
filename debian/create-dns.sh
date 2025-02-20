#!/bin/dash

sudo rm -rf /etc/resolv.conf
sudo tee /etc/resolv.conf > /dev/null << 'EOF'
nameserver 1.1.1.1
search .
EOF