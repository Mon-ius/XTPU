#!/bin/bash

set -eu

_USER=m0nius
_TEMPLATE=xvm
_ZONE_S0=us-west2-b
_ZONE_S1=asia-east1-b
_ZONE_S2=asia-northeast1-b

USER="${1:-$_USER}"
ZONE="${2:-$_ZONE_S1}"
TEMPLATE="${3:-$_TEMPLATE}"
XPASS="/tmp/$TEMPLATE"

rm -rf "$XPASS"

for i in {0..7}
do 
    VM_INSTANCE="${TEMPLATE}-${i}" 
    echo "Creating ${VM_INSTANCE}..."

    gcloud alpha compute instances create "$VM_INSTANCE" \
        --source-instance-template "$TEMPLATE" \
        --zone "$ZONE"  2>/dev/null || true
    
    _ip=$(gcloud compute instances describe "$VM_INSTANCE" --zone "$ZONE" | grep "natIP" | awk '{print $2}')

cat >> "$XPASS" <<-EOF
Host x$i
    User $USER
    Hostname $_ip
    Port 22
    ServerAliveInterval 15
    IdentityFile ~/.ssh/sec/xvm
EOF
done

cat "$XPASS"