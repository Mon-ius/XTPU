#!/bin/dash

set +e

TW_API_BASE="https://api.transferwise.com"
_TW_TOKEN_BASE64='base64encodedtoken'

if [ -z "$1" ]; then
    echo "Usage: $0 <wise_token>"
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg=="
    exit 1
fi

TW_TOKEN_BASE64="${1:-$_TW_TOKEN_BASE64}"
TW_TOKEN=$(echo "$TW_TOKEN_BASE64" | base64 -d)

TW_PROFILE_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $TW_TOKEN" "$TW_API_BASE/v2/profiles" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$TW_PROFILE_ID" ]; then
    echo "[ERROR] Unable to profile id. Please check your API token."
    exit 1
fi

echo "[INFO] Profile ID: TW_PROFILE_ID=$TW_PROFILE_ID"


# RESPONSE=$(curl -fsSL -X GET "$TW_API_BASE/v2/profiles" \
#     -H "Authorization: $TW_TOKEN" \
#     -H "Content-Type: application/json" \
#     -w "\nHTTP_STATUS:%{http_code}")

# HTTP_STATUS=$(echo "$RESPONSE" | sed -n 's/.*HTTP_STATUS:\([0-9]*\).*/\1/p')
# RESPONSE_BODY=$(echo "$RESPONSE" | sed 's/HTTP_STATUS:[0-9]*//')

# if [ "$HTTP_STATUS" = "200" ]; then
#     echo "$RESPONSE_BODY"
# else
#     echo "API key is not valid"
#     exit 1
# fi
