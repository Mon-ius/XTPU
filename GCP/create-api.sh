#!/bin/bash

_PROJECT_ID=$(gcloud config get-value project)
_KEY_NUM=10
_TARGET=generativelanguage.googleapis.com

PROJECT_ID="${1:-$_PROJECT_ID}"
KEY_NUM="${2:-$_KEY_NUM}"
TARGET="${3:-$_TARGET}"

KPASS="/tmp/$PROJECT_ID"

gcloud services enable "$TARGET"
# gcloud services list --enabled

for i in $(seq 1 "$KEY_NUM"); do
    _data=$(gcloud services api-keys create \
        --project="$PROJECT_ID" \
        --display-name="G-$i" \
        --api-target=service="$TARGET" \
        --format="json"
    )
    key=$(echo "$_data" | jq -r '.response.keyString')

cat >> "$KPASS" <<-EOF
{ key = '$key', model = 'gemini-1.5-pro-latest', url = 'https://$TARGET' },
EOF

done

cat "$KPASS"