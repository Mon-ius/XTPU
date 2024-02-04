#!/bin/bash

ZONE_S0=us-west2-b
ZONE_S1=asia-east1-b
ZONE_S2=asia-northeast1-b
TEMPLATE=xvm
XPASS=/tmp/xvm

rm -rf "$XPASS"

for i in {0..7}
do 
    VM_INSTANCE="${TEMPLATE}-${i}" 
    echo "Creating ${VM_INSTANCE}..."

    gcloud alpha compute instances create "$VM_INSTANCE" \
        --source-instance-template $TEMPLATE \
        --zone $ZONE_S1  2>/dev/null || true
    
    _ip=$(gcloud compute instances describe "$VM_INSTANCE" --zone $ZONE_S1 | grep "natIP" | awk '{print $2}')

cat >> "$XPASS" <<-EOF
Host z$i
    User m0nius
    Hostname $_ip
    Port 22
    ServerAliveInterval 15
    IdentityFile ~/.ssh/sec/xvm
EOF
done

cat "$XPASS"