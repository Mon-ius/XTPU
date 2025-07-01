#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token_base64>"
    echo "Example: $0 base64token"
    echo "Convert cloudflare token with R2 permission into S3 Access Key and Secret Key"
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

CF_ACCOUNT_ID=$(curl -fsSL "https://api.cloudflare.com/client/v4/accounts" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_ACCOUNT_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare account."
    exit 1
fi

echo "[INFO] Account ID: $CF_ACCOUNT_ID"


curl -fsSL -X POST "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/tokens/verify" \
    -H "Authorization: Bearer $CF_TOKEN"

TOKEN_RESPONSE=$(curl -fsSL "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/tokens/verify" \
    -H "Authorization: Bearer $CF_TOKEN")

