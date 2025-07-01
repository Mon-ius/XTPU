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

S3_ENDPOINT="https://$CF_ACCOUNT_ID.r2.cloudflarestorage.com"

echo "[INFO] Account ID: $CF_ACCOUNT_ID"

TOKEN_RESPONSE=$(curl -fsSL "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/tokens/verify" \
    -H "Authorization: Bearer $CF_TOKEN")

S3_ACCESS_KEY=$(echo "$TOKEN_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | sed 's/"id":"\([^"]*\)"/\1/')
S3_SECRET_KEY=$(echo -n "$CF_TOKEN" | sha256sum | cut -d' ' -f1)

echo "[SUCCESS] R2 to S3 generated"
echo "Endpoint: $S3_ENDPOINT"
echo "ACCESS KEY: $S3_ACCESS_KEY"
echo "SECRET KEY: $S3_SECRET_KEY"

