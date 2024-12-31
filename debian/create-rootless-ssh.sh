#!/bin/dash

cat <<'EOF' | sudo tee -a /etc/ssh/sshd_config
ChallengeResponseAuthentication no
PasswordAuthentication no
PermitRootLogin no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
EOF

sudo systemctl restart sshd