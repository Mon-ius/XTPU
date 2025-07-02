#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token_base64>"
    echo "Example: $0 base64token"
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

CF_DOMAIN=$(curl -fsSL "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_ZONE_ID=$(curl -fsSL "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_ACCOUNT_ID=$(curl -fsSL "https://api.cloudflare.com/client/v4/accounts" \
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

echo "[INFO] Account ID: $CF_ACCOUNT_ID"
echo "[INFO] Domain: $CF_DOMAIN"
echo "[INFO] Zone ID: $CF_ZONE_ID"
echo "[INFO] Creating token: $TOKEN_NAME"

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
                    "id": "1af1fa2adc104452b74a9a3364202f20",
                    "name": "Account Settings Write"
                },
                {
                    "id": "4755a26eedb94da69e1066d98aa820be",
                    "name": "DNS Write"
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
                    "id": "6c8a3737f07f46369c1ea1f22138daaf",
                    "name": "AI Gateway Write"
                },
                {
                    "id": "bacc64e0f6c34fc0883a1223f938a104",
                    "name": "Workers AI Write"
                },
                {
                    "id": "1af1fa2adc104452b74a9a3364202f20",
                    "name": "Account Settings Write"
                }
            ]
        }
    ]
}'

TOKEN_RESPONSE=$(curl -fsSL -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/tokens" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

TOKEN_ID=$(echo "$TOKEN_RESPONSE" | grep -o '"id":"[^"]*' | grep -o '[^"]*$' | head -n 1)
TOKEN_VALUE=$(echo "$TOKEN_RESPONSE" | grep -o '"value":"[^"]*' | cut -d'"' -f4)
SECRET_KEY=$(echo -n "$TOKEN_VALUE" | sha256sum | cut -d' ' -f1)

echo "[SUCCESS] Token created successfully"
echo "Token Value: $TOKEN_VALUE"
echo "Token ID/ACCESS_KEY: $TOKEN_ID"
echo "Token SECRET_KEY: $SECRET_KEY"


R2_ACCESS_KEY=$(echo "$TOKEN_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
R2_TOKEN_VALUE=$(echo "$TOKEN_RESPONSE" | grep -o '"value":"[^"]*' | cut -d'"' -f4)
R2_SECRET_KEY=$(echo -n "$R2_TOKEN_VALUE" | sha256sum | cut -d' ' -f1)

echo "[SUCCESS] R2 configured"
echo "Endpoint: $R2_ENDPOINT"
echo "ACCESS KEY: $R2_ACCESS_KEY"
echo "SECRET KEY: $R2_SECRET_KEY"

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

# curl -X PUT "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/tokens/$TOKEN_ID" \
#     -H "Authorization: Bearer $CF_TOKEN" \
#     -H "Content-Type: application/json" \
#     -d "$JSON_PAYLOAD"