#!/bin/dash

set +e

CF_API_BASE="https://api.cloudflare.com/client/v4"

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token>"
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg=="
    echo "Convert cloudflare token with R2 permission into S3 Access Key and Secret Key"
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

CF_ACCOUNT_ID=$(curl -fsSL -X GET "$CF_API_BASE/accounts" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_TOKEN_ID=$(curl -fsSL -X GET "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/verify" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_TOKEN" ]; then
    echo "[ERROR] Unable to decode token. Please check your base64 encoded token."
    exit 1
fi

if [ -z "$CF_ACCOUNT_ID" ]; then
    echo "[ERROR] Unable to retrieve Cloudflare account ID. Please check your API token."
    exit 1
fi

if [ -z "$CF_TOKEN_ID" ]; then
    echo "[ERROR] Unable to verify token. Please check your API token permissions."
    exit 1
fi

S3_ENDPOINT="https://$CF_ACCOUNT_ID.r2.cloudflarestorage.com"
S3_ACCESS_KEY="$CF_TOKEN_ID"
S3_SECRET_KEY=$(echo -n "$CF_TOKEN" | sha256sum | cut -d' ' -f1)

echo "[INFO] Account ID: CF_ACCOUNT_ID=$CF_ACCOUNT_ID"
echo "[INFO] Token ID: CF_TOKEN_ID=$CF_TOKEN_ID"
echo "[INFO] Endpoint: S3_ENDPOINT=$S3_ENDPOINT"

if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
    echo "[ERROR] Failed to generate S3 credentials. Please check your API token has R2 permissions."
    exit 1
fi

echo "[SUCCESS] R2 to S3 credentials generated successfully."
echo "S3_ENDPOINT=$S3_ENDPOINT"
echo "S3_ACCESS_KEY=$S3_ACCESS_KEY"
echo "S3_SECRET_KEY=$S3_SECRET_KEY"