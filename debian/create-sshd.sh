#!/bin/dash

export DEBIAN_FRONTEND=noninteractive

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y openssh-server

sudo tee /etc/ssh/sshd_config > /dev/null << 'EOF'
Include /etc/ssh/sshd_config.d/*.conf
KbdInteractiveAuthentication no
UsePAM yes
PrintMotd no
AcceptEnv LANG LC_*

ChallengeResponseAuthentication no
PasswordAuthentication no
PermitRootLogin no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
X11Forwarding yes
GatewayPorts yes
ClientAliveInterval 60
ClientAliveCountMax 3
EOF

sudo systemctl restart sshd