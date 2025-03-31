#!/bin/dash

export DEBIAN_FRONTEND=noninteractive

sudo tee /etc/systemd/journald.conf > /dev/null << 'EOF'
[Journal]
SystemMaxUse=512M
SystemMaxFileSize=128M
RuntimeMaxUse=64M
ForwardToSyslog=no
EOF

sudo journalctl --rotate && sudo journalctl --vacuum-time=1s
sudo systemctl restart systemd-journald