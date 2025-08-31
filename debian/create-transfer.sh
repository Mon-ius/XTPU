#!/bin/dash

set +e

WISE_API_BASE="https://api.transferwise.com"
_WISE_TOKEN_BASE64='base64encodedtoken'

if [ -z "$1" ]; then
    echo "Usage: $0 <wise_token>"
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg=="
    exit 1
fi

WISE_TOKEN_BASE64="${1:-$_WISE_TOKEN_BASE64}"

WISE_TOKEN="Bearer $(echo "$WISE_TOKEN_BASE64" | base64 -d)"

RESPONSE=$(curl -fsSL -X GET "$WISE_API_BASE/v2/profiles" \
    -H "Authorization: $WISE_TOKEN" \
    -H "Content-Type: application/json" \
    -w "\nHTTP_STATUS:%{http_code}")

HTTP_STATUS=$(echo "$RESPONSE" | sed -n 's/.*HTTP_STATUS:\([0-9]*\).*/\1/p')
RESPONSE_BODY=$(echo "$RESPONSE" | sed 's/HTTP_STATUS:[0-9]*//')

if [ "$HTTP_STATUS" = "200" ]; then
    echo "$RESPONSE_BODY"
else
    echo "API key is not valid"
    exit 1
fi