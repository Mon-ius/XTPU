#!/bin/dash

END_POINT="https://api.cloudflareclient.com/v0a2077/reg"
API_VERSION="a-7.21-0721"

keypair=$(openssl genpkey -algorithm X25519)
private_key=$(echo "$keypair" | openssl pkey -outform DER | tail -c 32 | base64)
public_key=$(echo "$keypair" | openssl pkey -pubout -outform DER | tail -c 32 | base64)

RESPONSE=$(curl -fsSL -X POST $END_POINT \
    -H "Content-Type: application/json" \
    -H "CF-Client-Version: $API_VERSION" \
    -d '{
        "key":"'${public_key}'",
        "tos":"'$(date +"%Y-%m-%dT%H:%M:%S.000Z")'"
    }')

echo "$RESPONSE"