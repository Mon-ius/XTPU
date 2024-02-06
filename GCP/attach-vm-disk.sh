#!/bin/bash

set -eu

_VM_NAME=xvm-1
_DISK=disk-01
_ZONE_S0=us-west2-b
_ZONE_S1=asia-east1-b
_ZONE_S2=asia-northeast1-b

VM_NAME="${3:-$_VM_NAME}"
ZONE="${2:-$_ZONE_S1}"
DISK="${1:-$_DISK}"

gcloud compute instances attach-disk "$VM_NAME" --disk "$DISK" --zone "$ZONE"