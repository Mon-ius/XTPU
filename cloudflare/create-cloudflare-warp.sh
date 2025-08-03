#!/bin/dash

set +e

CF_WARP_BASE="https://api.cloudflareclient.com/v0a2025/reg"

TOS=$(date --utc +"%Y-%m-%dT%H:%M:%S.%3NZ" | awk '{print substr($0, 1, length($0)-1)"-02:00"}')

SECRET_KEY=$(openssl genpkey -algorithm X25519)

private_key=$(echo "$SECRET_KEY" | openssl pkey -outform DER | tail -c 32 | base64)
public_key=$(echo "$SECRET_KEY" | openssl pkey -pubout -outform DER | tail -c 32 | base64)

WARP_PAYLOAD='{
    "tos": "'"$TOS"'",
    "key": "'"$public_key"'",
    "referrer": "'"$_REF"'"
}'

RESPONSE=$(curl -s -X POST "$CF_WARP_BASE" \
    -H "Content-Type: application/json" \
    -d "$WARP_PAYLOAD")

CF_ACCOUNT_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_CLIENT_ID=$(echo "$RESPONSE" | grep -o '"client_id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_TOKEN_ID=$(echo "$RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_LICENSE=$(echo "$RESPONSE" | grep -o '"license":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_ADDR_V4=$(echo "$RESPONSE" | grep -o '"v4":"[^"]*' | cut -d'"' -f4 | tail -n 1)
CF_ADDR_V6=$(echo "$RESPONSE" | grep -o '"v6":"[^"]*' | cut -d'"' -f4 | tail -n 1)

WARP_RESPONSE='{
    "account": "'"$CF_ACCOUNT_ID"'",
    "license": "'"$CF_LICENSE"'",
    "client": "'"$CF_CLIENT_ID"'",
    "token": "'"$CF_TOKEN_ID"'",
    "v4": "'"$CF_ADDR_V4"'",
    "v6": "'"$CF_ADDR_V6"'",
    "key": "'"$private_key"'"
}'

echo "$WARP_RESPONSE"