#!/bin/dash

SEED="2f33026e-003e-4f9e-a319-2ace161bac4d"
END_POINT="https://api.cloudflareclient.com/v0a2077"
REG_URL="$END_POINT/reg"

seed="${1:-$SEED}"
tos=$(date +"%Y-%m-%dT%H:%M:%S.000Z")
key="$(echo "$tos" | sha256sum | head -c 43)="

RESPONSE=$(curl -fsSL $REG_URL \
    -d '{
        "key":"'${key}'",
        "tos":"'${tos}'"
    }')

id=$(echo "$RESPONSE" | grep -oP '"id":"\K[^"]+' | head -n 1) 
token=$(echo "$RESPONSE" | grep -oP '"token":"\K[^"]+' | head -n 1) 
license=$(echo "$RESPONSE" | grep -oP '"license":"\K[^"]+' | head -n 1)

curl -fsSL -o /dev/null -X PUT "$REG_URL/$id/account" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{
        "license":"'${seed}'"
    }'

curl -fsSL -o /dev/null -X PUT "$REG_URL/$id/account" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d '{
        "license":"'${license}'"
    }'

INFO=$(curl -fsSL "$REG_URL/$id/account" -H "Authorization: Bearer $token")
DELETE=$(curl -fsSL -X DELETE "$REG_URL/$id" -H "Authorization: Bearer $token")

quota=$(echo "$INFO" | grep -oP '"quota":\K\d+')

# echo "\"id\":\"$id\""
# echo "\"key\":\"$key\""
# echo "\"token\":\"$token\""
# echo "\"license\":\"$license\""
# echo "\"quota\":\"$quota\""
echo "$token"

