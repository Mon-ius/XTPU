#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <vonage_base64> <number> <brand>"
    echo "Example: $0 base64token +1234567890 example.com"
    exit 1
fi

_VONAGE_TOKEN_BASE64='base64encodedtoken'
_VONAGE_NUMBER='+1234567890'
_VONAGE_BRAND='example.com'

VONAGE_TOKEN_BASE64="${1:-$_VONAGE_TOKEN_BASE64}"
VONAGE_NUMBER="${2:-$_VONAGE_NUMBER}"
VONAGE_BRAND="${3:-$_VONAGE_BRAND}"

VONAGE_TOKEN=$(echo "$VONAGE_TOKEN_BASE64" | base64 -d)
VONAGE_API_KEY=$(echo "$VONAGE_TOKEN" | cut -d: -f1)
VONAGE_API_SECRET=$(echo "$VONAGE_TOKEN" | cut -d: -f2)

if [ -z "$VONAGE_API_KEY" ] || [ -z "$VONAGE_API_SECRET" ]; then
    echo "Error: Could not extract API credentials from base64 token"
    echo "Token should be base64 encoded 'api_key:api_secret'"
    exit 1
fi

# RESPONSE=$(curl -fsSL -X GET "https://api.nexmo.com/verify/json?&api_key=$VONAGE_API_KEY&api_secret=$VONAGE_API_SECRET&number=$VONAGE_NUMBER&brand=$VONAGE_BRAND")
RESPONSE=$(curl -fsSL -X POST "https://api.nexmo.com/verify/json" \
    -d "api_key=$VONAGE_API_KEY" \
    -d "api_secret=$VONAGE_API_SECRET" \
    -d "number=$VONAGE_NUMBER" \
    -d "brand=$VONAGE_BRAND")

REQUEST_ID=$(echo "$RESPONSE" | sed -n 's/.*"request_id":"\([^"]*\)".*/\1/p')
STATUS=$(echo "$RESPONSE" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')

if [ "$STATUS" = "0" ] && [ -n "$REQUEST_ID" ]; then
    echo "Request ID: $REQUEST_ID"
else
    echo "Full response: $RESPONSE"
fi

# RESPONSE=$(curl -s -X POST "https://api.nexmo.com/verify/json" \
#     -d "api_key=$VONAGE_API_KEY" \
#     -d "api_secret=$VONAGE_API_SECRET" \
#     -d "number=$VONAGE_NUMBER" \
#     -d "brand=$VONAGE_BRAND")