#!/bin/bash

_TARGET=generativelanguage.googleapis.com
_PROJECT_ID=g-api
_KEY_NUM=5

TARGET="${1:-$_TARGET}"
PROJECT_ID="${2:-$_PROJECT_ID}"
KEY_NUM="${3:-$_KEY_NUM}"

KPASS="/tmp/kpass"

for i in $(seq 1 "$KEY_NUM"); do
    key_data=$(gcloud services api-keys create \
        --project="$PROJECT_ID" \
        --display-name="G-$i" \
        --api-target=service="$TARGET" \
        --format="json"
    )

    echo "$key_data" | jq -r '.response.keyString' | tee -a $KPASS
done

cat $KPASS