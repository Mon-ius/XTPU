#!/bin/dash

END_POINT="https://api.cloudflareclient.com/v0a2077"
REG_URL="$END_POINT/reg"

keypair=$(openssl genpkey -algorithm X25519)
private_key=$(echo "$keypair" | openssl pkey -outform DER | tail -c 32 | base64)
public_key=$(echo "$keypair" | openssl pkey -pubout -outform DER | tail -c 32 | base64)

RESPONSE=$(curl -fsSL $REG_URL \
    -d '{
        "key":"'${public_key}'",
        "tos":"'$(date +"%Y-%m-%dT%H:%M:%S.000Z")'"
    }')

id=$(echo "$RESPONSE" | grep -oP '"id":"\K[^"]+' | head -n 1) 
token=$(echo "$RESPONSE" | grep -oP '"token":"\K[^"]+' | head -n 1) 
license=$(echo "$RESPONSE" | grep -oP '"license":"\K[^"]+' | head -n 1)

echo "\"id\":\"$id\""
echo "\"token\":\"$token\""
echo "\"license\":\"$license\""
# echo "$RESPONSE"