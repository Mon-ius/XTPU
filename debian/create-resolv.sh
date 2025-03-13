#!/bin/dash

sudo rm -rf /etc/resolv.conf
sudo tee /etc/resolv.conf > /dev/null << 'EOF'
nameserver 1.1.1.1
search .
EOF

sudo chattr +i /etc/resolv.conf
sudo tee /etc/dpkg/dpkg.cfg.d/resolv-conf-protect > /dev/null << 'EOF'
path-exclude=/etc/resolv.conf
EOF

sudo tee /etc/apt/apt.conf.d/100-resolv-conf-protect > /dev/null << 'EOF'
DPkg::Post-Invoke {"chattr +i /etc/resolv.conf || true";};
EOF