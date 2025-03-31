#!/bin/dash

export DEBIAN_FRONTEND=noninteractive

cat <<'EOF' > /etc/systemd/journald.conf
[Journal]
SystemMaxUse=512M
SystemMaxFileSize=128M
RuntimeMaxUse=64M
ForwardToSyslog=no
EOF

sudo systemctl restart systemd-journald