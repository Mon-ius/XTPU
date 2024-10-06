#!/bin/dash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

RUSER="$1"

if id "$RUSER" >/dev/null 2>&1; then
    echo "Error: User '$RUSER' already exists."
    exit 1
else
    echo "Creating..."
fi

RHOME="/home/$RUSER"
ROOT_KEYS=/data/keys
PRIVATE="/tmp/id_ed25519_$RUSER" 

#User creation
sudo adduser --disabled-password --gecos "" "$RUSER"

#User ssh-key creation
ssh-keygen -t ed25519 -f "$PRIVATE" -q -N ''
PUBKEY=$(sed "s/$USER/$RUSER/" "$PRIVATE.pub")
rm -rf "$PRIVATE.pub" && sudo mkdir -p $ROOT_KEYS

sudo su "$RUSER" -c "
    mkdir -p ~/.ssh &&
    touch ~/.ssh/authorized_keys &&
    echo $PUBKEY >> ~/.ssh/authorized_keys
"

sudo mv "$PRIVATE" "$RHOME" && sudo chown "$RUSER:$RUSER" "$RHOME/id_ed25519_$RUSER"
echo "SSH key generated and added for $RUSER, the private key in $RHOME/id_ed25519_$RUSER"

sudo cp "$RHOME/id_ed25519_$RUSER" $ROOT_KEYS
echo "Backup private key in $ROOT_KEYS/id_ed25519_$RUSER"

if command -v docker > /dev/null 2>&1; then
    echo "Docker is installed. Adding $RUSER to the docker group."
    sudo usermod -aG docker "$RUSER"
else
    echo "Docker is not installed. Please install Docker first."
fi

RPASS=$(echo "$PUBKEY" | md5sum | awk '{ print $1 }')
echo "$RUSER:$RPASS" | sudo chpasswd

echo "Finished..."
echo ">  Login username: $RUSER"
echo ">  Password login disabled: $RPASS"
echo ">  Use private key to ssh $RUSER@127.0.0.1 -p 22 -i $RUSER this machine!"
sudo cat "$ROOT_KEYS/id_ed25519_$RUSER"