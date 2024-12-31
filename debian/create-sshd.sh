#!/bin/dash

sudo apt-get update && sudo apt install openssh-server -y

cat <<'EOF' | sudo tee /etc/ssh/sshd_config
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