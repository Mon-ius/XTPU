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

CF_ACCOUNT_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_TOKEN_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/verify" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_ZONE_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/$CF_TOKEN_ID" | grep -o 'com.cloudflare.api.account.zone.[^"]*' | sed 's/.*\.zone\.//')

if [ -z "$CF_ACCOUNT_ID" ]; then
    echo "Error: Unable to retrieve account ID. Please check your API token."
    echo "Required permissions: Account:Account API Tokens:Read"
    exit 1
fi

if [ -z "$CF_ZONE_ID" ]; then
    echo "Error: Unable to retrieve zone ID. Please check your API token permissions."
    echo "Required permissions: Account:Account API Tokens:Read"
    exit 1
fi

CF_DOMAIN=$(curl -fsSL -X GET "$CF_API_BASE/zones/$CF_ZONE_ID" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_DOMAIN" ]; then
    echo "Error: Unable to retrieve Cloudflare domain."
    exit 1
fi

echo "[INFO] Account ID: CF_ACCOUNT_ID=$CF_ACCOUNT_ID"
echo "[INFO] Domain: CF_DOMAIN=$CF_DOMAIN"
echo "[INFO] Zone ID: CF_ZONE_ID=$CF_ZONE_ID"

echo "[INFO] Updating SSL settings for zone $CF_ZONE_ID..."

curl -fsSL -X PATCH "$CF_API_BASE/zones/$CF_ZONE_ID/settings/ssl" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"value":"strict"}'

curl -fsSL -X PATCH "$CF_API_BASE/zones/$CF_ZONE_ID/settings/automatic_https_rewrites" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"value":"on"}'

curl -fsSL -X PATCH "$CF_API_BASE/zones/$CF_ZONE_ID/settings/min_tls_version" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"value":"1.3"}'

# curl -fsSL https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/cloudflare/account/create-cloudflare-zone.sh | sh -s -- token