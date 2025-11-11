#!/bin/dash

if [ -z "$1" ]; then
    echo "Usage: $0 <usr> [passwd]"
    echo "Example: $0 test p4ssWd"
    exit 1
fi

_XUSER='test'
_XPASS='p4ssWd'

XUSER="${1:-$_XUSER}"
XPASS="${2:-$_XPASS}"

if id "$XUSER" >/dev/null 2>&1; then
    echo "Error: User '$XUSER' already exists."
        exit 1
else
    echo "Creating..."
        echo ">  user: $XUSER"
        echo ">  password: $XPASS"
fi

XHOME="/home/$XUSER"
KEYS_STORE=/data/keys
PRIVATE="/tmp/id_ed25519_$XUSER"

sudo adduser --disabled-password --gecos "" "$XUSER"
sudo chown -R "$XUSER:$XUSER" "$XHOME"
echo "$XUSER:$XPASS" | sudo chpasswd

ssh-keygen -t ed25519 -f "$PRIVATE" -q -N ''
PUBKEY=$(sed "s/$USER/$XUSER/" "$PRIVATE.pub")
rm -rf "$PRIVATE.pub" && sudo mkdir -p $KEYS_STORE

sudo su "$XUSER" -c "mkdir -p ~/.ssh"
sudo su "$XUSER" -c "touch ~/.ssh/authorized_keys"
sudo su "$XUSER" -c "echo $PUBKEY >> ~/.ssh/authorized_keys"

sudo mv "$PRIVATE" "$XHOME" && sudo chown "$XUSER:$XUSER" "$XHOME/id_ed25519_$XUSER"
echo "SSH key generated and added for $XUSER, the private key in $XHOME/id_ed25519_$XUSER"

sudo cp "$XHOME/id_ed25519_$XUSER" $KEYS_STORE
echo "Backup private key in $KEYS_STORE/id_ed25519_$XUSER"
sudo cat "$KEYS_STORE/id_ed25519_$XUSER"