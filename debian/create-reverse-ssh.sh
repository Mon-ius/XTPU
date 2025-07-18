#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <remote> <port>"
    echo "Example: $0 127.0.0.1 60022"
    exit 1
fi

_RHOST=127.0.0.1
_RPORT=60022
SNAME=reverse-ssh

RHOST="${1:-$_RHOST}"
RPORT="${2:-$_RPORT}"
SECRET=/home/$USER/.ssh/id_ed25519

echo "[Unit]
Description=$SNAME service
After=network.target
Wants=network-online.target
StartLimitInterval=200
StartLimitBurst=1

[Service]
Type=simple
User=$USER
StandardOutput=null
StandardError=null
ExecStart=ssh -i $SECRET -NC -o GatewayPorts=true -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -R $RPORT:127.0.0.1:22 $USER@$RHOST
ExecStopPost=/usr/bin/ssh-keygen -R $RHOST
ExecStop=/bin/true
SuccessExitStatus=0 1
Restart=on-failure
RestartSec=300

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/$SNAME.service

echo "[Unit]
Description=Timer for the $SNAME service

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target" | sudo tee "/etc/systemd/system/$SNAME.timer"

sudo systemctl daemon-reload
sudo systemctl stop $SNAME.timer
sudo systemctl disable $SNAME.timer
sudo systemctl stop $SNAME
sudo systemctl disable $SNAME
sudo systemctl enable $SNAME.timer
sudo systemctl start $SNAME.timer
sudo systemctl status $SNAME.timer
