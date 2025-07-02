#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token_base64> [github_username]"
    echo "Example: $0 base64token github"
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'
_GITHUB='github'

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)
GITHUB="${2:-$_GITHUB}"

CF_DOMAIN=$(curl -fsSL -X GET "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_ZONE_ID=$(curl -fsSL -X GET "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_ACCOUNT_ID=$(curl -fsSL -X GET "https://api.cloudflare.com/client/v4/accounts" \
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

echo "[INFO] Account ID: $CF_ACCOUNT_ID"
echo "[INFO] Domain: $CF_DOMAIN"
echo "[INFO] Zone ID: $CF_ZONE_ID"


JSON_PAYLOAD='{
    "targets": [
        {
            "target": "url",
            "constraint": {
                "operator": "matches",
                "value": "'"${CF_DOMAIN}"'"
            }
        }
    ],
    "actions": [
        {
            "id": "forwarding_url",
            "value": {
                "url": "https://github.com/'"${GITHUB}"'",
                "status_code": 301
            }
        }
    ],
    "status": "active"
}'

RESPONSE=$(curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD")

echo "$RESPONSE"