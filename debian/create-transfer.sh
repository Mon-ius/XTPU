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

echo "Verifying Wise API credentials..."
echo "API Endpoint: $WISE_API_BASE/v2/profiles"
echo ""

RESPONSE=$(curl -fsSL -X GET "$WISE_API_BASE/v2/profiles" \
    -H "Authorization: $WISE_TOKEN" \
    -H "Content-Type: application/json" \
    -w "\nHTTP_STATUS:%{http_code}")

HTTP_STATUS=$(echo "$RESPONSE" | sed -n 's/.*HTTP_STATUS:\([0-9]*\).*/\1/p')
RESPONSE_BODY=$(echo "$RESPONSE" | sed 's/HTTP_STATUS:[0-9]*//')

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✓ API Key is valid!"
    echo ""
    
    PROFILE_COUNT=$(echo "$RESPONSE_BODY" | grep -o '"id":[0-9]*' | wc -l)
    echo "Found $PROFILE_COUNT profile(s):"
    echo ""
    
    PROFILE_IDS=$(echo "$RESPONSE_BODY" | sed -n 's/.*"id":\([0-9]*\).*/\1/p')
    PROFILE_TYPES=$(echo "$RESPONSE_BODY" | sed -n 's/.*"type":"\([^"]*\)".*/\1/p')
    PROFILE_NAMES=$(echo "$RESPONSE_BODY" | sed -n 's/.*"fullName":"\([^"]*\)".*/\1/p')
    
    i=1
    echo "$PROFILE_IDS" | while IFS= read -r profile_id; do
        profile_type=$(echo "$PROFILE_TYPES" | sed -n "${i}p")
        profile_name=$(echo "$PROFILE_NAMES" | sed -n "${i}p")
        
        echo "Profile #$i:"
        echo "  ID: $profile_id"
        echo "  Type: $profile_type"
        if [ -n "$profile_name" ]; then
            echo "  Name: $profile_name"
        fi
        echo ""
        
        i=$((i + 1))
    done
    
    FIRST_PROFILE_ID=$(echo "$PROFILE_IDS" | head -n1)
    echo "Primary Profile ID: $FIRST_PROFILE_ID"
    
elif [ "$HTTP_STATUS" = "401" ]; then
    echo "✗ Authentication failed!"
    echo "HTTP Status: 401 Unauthorized"
    echo ""
    echo "Error details:"
    echo "$RESPONSE_BODY" | sed 's/,/,\n/g' | sed 's/{/{\n/g' | sed 's/}/\n}/g'
    echo ""
    echo "Please check your API token."
    exit 1
    
elif [ "$HTTP_STATUS" = "403" ]; then
    echo "✗ Access forbidden!"
    echo "HTTP Status: 403 Forbidden"
    echo ""
    echo "Error details:"
    echo "$RESPONSE_BODY" | sed 's/,/,\n/g' | sed 's/{/{\n/g' | sed 's/}/\n}/g'
    echo ""
    echo "Your API token doesn't have permission to access profiles."
    exit 1
    
elif [ -z "$HTTP_STATUS" ]; then
    echo "✗ Connection failed!"
    echo "Could not connect to Wise API."
    echo "Please check your internet connection."
    exit 1
    
else
    echo "✗ Unexpected error!"
    echo "HTTP Status: $HTTP_STATUS"
    echo ""
    echo "Response:"
    echo "$RESPONSE_BODY" | sed 's/,/,\n/g' | sed 's/{/{\n/g' | sed 's/}/\n}/g'
    exit 1
fi