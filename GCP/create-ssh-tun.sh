#!/bin/dash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <username> <pem>"
    exit 1
fi

RUSER=$1
PEM=$2
sudo adduser --disabled-password --disabled-login --gecos "" "$RUSER"
sudo mkdir -p "/home/$RUSER/.ssh"
echo "$PEM" | sudo tee "/home/$RUSER/.ssh/authorized_keys"
sudo chown -R "$RUSER:$RUSER" "/home/$RUSER/.ssh"