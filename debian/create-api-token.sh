#!/bin/dash

set +e

CF_API_BASE="https://api.cloudflare.com/client/v4"

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token>"
    echo "Example: $0 base64token"
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

CF_DOMAIN=$(curl -fsSL -X GET "$CF_API_BASE/zones" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_ZONE_ID=$(curl -fsSL -X GET "$CF_API_BASE/zones" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_ACCOUNT_ID=$(curl -fsSL -X GET "$CF_API_BASE/accounts" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_ACCOUNT_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare account."
    exit 1
fi

if [ -z "$CF_DOMAIN" ]; then
    echo "Error: Unable to retrieve Cloudflare domain."
    exit 1
fi

if [ -z "$CF_ZONE_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare zone ID."
    exit 1
fi

TOKEN_NAME="$CF_DOMAIN-$(date +%Y%m%d)"

echo "[INFO] Account ID: CF_ACCOUNT_ID=$CF_ACCOUNT_ID"
echo "[INFO] Domain: CF_DOMAIN=$CF_DOMAIN"
echo "[INFO] Zone ID: CF_ZONE_ID=$CF_ZONE_ID"
echo "[INFO] Creating token: TOKEN_NAME=$TOKEN_NAME"

# JSON_PAYLOAD='{
#     "name": "'"${TOKEN_NAME}"'",
#     "policies": [
#         {
#             "effect": "allow",
#             "resources": {
#                 "com.cloudflare.api.account.'"${CF_ACCOUNT_ID}"'": "*"
#             },
#             "permission_groups": [
#                 {
#                     "id": "4755a26eedb94da69e1066d98aa820be",
#                     "name": "DNS Write"
#                 },
#                 {
#                     "id": "c8fed203ed3043cba015a93ad1616f1f",
#                     "name": "Zone Read"
#                 },
#                 {
#                     "id": "1af1fa2adc104452b74a9a3364202f20",
#                     "name": "Account Settings Write"
#                 },
#                 {
#                     "id": "b4992e1108244f5d8bfbd5744320c2e1",
#                     "name": "Workers R2 Storage Read"
#                 },
#                 {
#                     "id": "bf7481a1826f439697cb59a20b22293e",
#                     "name": "Workers R2 Storage Write"
#                 },
#                 {
#                     "id": "45db74139a62490b9b60eb7c4f34994b",
#                     "name": "Workers R2 Data Catalog Read"
#                 },
#                 {
#                     "id": "d229766a2f7f4d299f20eaa8c9b1fde9",
#                     "name": "Workers R2 Data Catalog Write"
#                 },
#                 {
#                     "id": "f7f0eda5697f475c90846e879bab8666",
#                     "name": "Workers KV Storage Write"
#                 },
                # {
                #     "id": "e086da7e2179491d91ee5f35b3ca210a",
                #     "name": "Workers Scripts Write"
                # },
#                 {
#                     "id": "bacc64e0f6c34fc0883a1223f938a104",
#                     "name": "Workers AI Write"
#                 },
#                 {
#                     "id": "2e095cf436e2455fa62c9a9c2e18c478",
#                     "name": "Workers CI Write"
#                 },
#                 {
#                     "id": "bdbcd690c763475a985e8641dddc09f7",
#                     "name": "Workers Containers Write"
#                 },
#                 {
#                     "id": "28f4b596e7d643029c524985477ae49a",
#                     "name": "Workers Routes Write"
#                 },
#                 {
#                     "id": "6c8a3737f07f46369c1ea1f22138daaf",
#                     "name": "AI Gateway Write"
#                 }
#             ]
#         }
#     ]
# }'

JSON_PAYLOAD='{
    "name": "'"${TOKEN_NAME}"'",
    "policies": [
        {
            "effect": "allow",
            "resources": {
                "com.cloudflare.api.account.'"${CF_ACCOUNT_ID}"'": "*"
            },
            "permission_groups": [
                {
                    "id": "eb56a6953c034b9d97dd838155666f06",
                    "name": "Account API Tokens Read"
                },
                {
                    "id": "e086da7e2179491d91ee5f35b3ca210a",
                    "name": "Workers Scripts Write"
                },
                {
                    "id": "4755a26eedb94da69e1066d98aa820be",
                    "name": "DNS Write"
                },
                {
                    "id": "c8fed203ed3043cba015a93ad1616f1f",
                    "name": "Zone Read"
                },
                {
                    "id": "1af1fa2adc104452b74a9a3364202f20",
                    "name": "Account Settings Write"
                },
                {
                    "id": "b4992e1108244f5d8bfbd5744320c2e1",
                    "name": "Workers R2 Storage Read"
                },
                {
                    "id": "bf7481a1826f439697cb59a20b22293e",
                    "name": "Workers R2 Storage Write"
                },
                {
                    "id": "45db74139a62490b9b60eb7c4f34994b",
                    "name": "Workers R2 Data Catalog Read"
                },
                {
                    "id": "d229766a2f7f4d299f20eaa8c9b1fde9",
                    "name": "Workers R2 Data Catalog Write"
                },
                {
                    "id": "f7f0eda5697f475c90846e879bab8666",
                    "name": "Workers KV Storage Write"
                },
                {
                    "id": "bacc64e0f6c34fc0883a1223f938a104",
                    "name": "Workers AI Write"
                },
                {
                    "id": "2e095cf436e2455fa62c9a9c2e18c478",
                    "name": "Workers CI Write"
                },
                {
                    "id": "bdbcd690c763475a985e8641dddc09f7",
                    "name": "Workers Containers Write"
                },
                {
                    "id": "28f4b596e7d643029c524985477ae49a",
                    "name": "Workers Routes Write"
                },
                {
                    "id": "6c8a3737f07f46369c1ea1f22138daaf",
                    "name": "AI Gateway Write"
                }
            ]
        }
    ]
}'

RESPONSE=$(curl -fsSL -X POST "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

TOKEN_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | grep -o '[^"]*$' | head -n 1)
TOKEN_VALUE=$(echo "$RESPONSE" | grep -o '"value":"[^"]*' | cut -d'"' -f4)
TOKEN_BASE64=$(echo "$TOKEN_VALUE" | base64 -w 0)
SECRET_KEY=$(echo -n "$TOKEN_VALUE" | sha256sum | cut -d' ' -f1)

echo "[SUCCESS] Token created successfully"
echo "Token ID/ACCESS_KEY: TOKEN_ID='$TOKEN_ID'"
echo "Token Value: CF_TOKEN='$TOKEN_VALUE'"
echo "Token BASE64: CF_TOKEN_BASE64='$TOKEN_BASE64'"
echo "Token SECRET_KEY: $SECRET_KEY"

# JSON_PAYLOAD='{
#     "name": "'"${TOKEN_NAME}"'",
#     "policies": [
#         {
#             "effect": "allow",
#             "resources": {
#                 "com.cloudflare.api.account.zone.'"${CF_ZONE_ID}"'": "*"
#             },
#             "permission_groups": [
#                 {
#                     "id": "4755a26eedb94da69e1066d98aa820be"
#                 }
#             ]
#         }
#     ]
# }'

# curl -X PUT "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/$TOKEN_ID" \
#     -H "Authorization: Bearer $CF_TOKEN" \
#     -H "Content-Type: application/json" \
#     -d "$JSON_PAYLOAD"