#!/bin/dash

set +e

CF_API_BASE="https://api.cloudflare.com/client/v4"

_CF_TOKEN_BASE64="base64encodedtoken"
_CF_HOSTNAME="custom.example.com"
_CF_ORIGIN="origin.example.com"

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token> [hostname] [origin_server]"
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== custom.example.com origin.example.com"
    exit 1
fi

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_HOSTNAME="${2:-$_CF_HOSTNAME}"
CF_ORIGIN="${3:-$_CF_ORIGIN}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

CF_ACCOUNT_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_TOKEN_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/verify" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_ZONE_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/$CF_TOKEN_ID" | grep -o 'com.cloudflare.api.account.zone.[^"]*' | sed 's/.*\.zone\.//') 
CF_EXISTING=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/zones/$CF_ZONE_ID/custom_hostnames?hostname=$CF_HOSTNAME" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_ACCOUNT_ID" ]; then
    echo "Error: Unable to retrieve account ID. Please check your API token."
    exit 1
fi

if [ -z "$CF_ZONE_ID" ]; then
    echo "Error: Unable to retrieve zone ID. Please check your API token permissions."
    exit 1
fi

if [ -n "$CF_EXISTING" ]; then
    echo "Error: Custom hostname already exists: $CF_HOSTNAME (ID: $CF_EXISTING)"
    exit 1
fi

echo "[INFO] Account ID: CF_ACCOUNT_ID=$CF_ACCOUNT_ID"
echo "[INFO] Zone ID: CF_ZONE_ID=$CF_ZONE_ID"
echo "[INFO] Hostname: CF_HOSTNAME=$CF_HOSTNAME"
echo "[INFO] Origin Server: CF_ORIGIN=$CF_ORIGIN"

CUSTOM_HOSTNAME_PAYLOAD='{
    "hostname": "'"$CF_HOSTNAME"'",
    "custom_origin_server": "'"$CF_ORIGIN"'",
    "ssl": {
        "cloudflare_branding": true
    }
}'

echo "[INFO] Creating custom hostname..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$CF_API_BASE/zones/$CF_ZONE_ID/custom_hostnames" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CUSTOM_HOSTNAME_PAYLOAD")

if [ "$RESPONSE" -eq 201 ] || [ "$RESPONSE" -eq 200 ]; then
    echo "[SUCCESS] Custom hostname $CF_HOSTNAME with origin $CF_ORIGIN has been created."
    
    CF_NEW_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/zones/$CF_ZONE_ID/custom_hostnames?hostname=$CF_HOSTNAME" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
    echo "[INFO] Custom hostname ID: $CF_NEW_ID"
else
    echo "[ERROR] Failed to create custom hostname $CF_HOSTNAME. HTTP status code: $RESPONSE"
    exit 1
fi

# curl -fsSL https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/cloudflare/account/create-cloudflare-token.sh | sh -s -- root_token
# curl -fsSL https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/cloudflare/account/create-cloudflare-saas.sh | sh -s -- token custom.example.xyz origin.example.com