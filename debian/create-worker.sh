#!/bin/dash

set +e

CF_API_BASE="https://api.cloudflare.com/client/v4"

if [ -z "$1" ]; then
    echo "Usage: $0 <base64-encoded-cf-api-token> [service-name] [worker-content]"
    echo ""
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== my-service worker.js"
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'
_SERVICE_NAME="worker-$(date +%Y%m%d)-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 8)"
# _CLOUDFLARE_ACCELERATION='cf.090227.xyz'
_WORKER_CONETENT=$(cat <<EOF
export default {
    async fetch(request) {
        const url = new URL(request.url);
        return new Response(JSON.stringify({
            message: "Hello from Cloudflare Workers!",
            serviceName: "$_SERVICE_NAME",
            timestamp: new Date().toISOString(),
            path: url.pathname,
            method: request.method
        }), {
            headers: {
                'Content-Type': 'application/json'
            }
        });
    }
};
EOF
)

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
SERVICE_NAME="${2:-$_SERVICE_NAME}"
WORKER_CONETENT="${3:-$WORKER_CONETENT}"
# CLOUDFLARE_ACCELERATION="${4:-$_CLOUDFLARE_ACCELERATION}"

CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

echo "🔍 Fetching account information..."

CF_ACCOUNT_ID=$(curl -fsSL -X GET "$CF_API_BASE/accounts" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_TOKEN_ID=$(curl -fsSL -X GET "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/verify"  \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_ZONE_ID=$(curl -fsSL -X GET "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/$CF_TOKEN_ID" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o 'com.cloudflare.api.account.zone.[^"]*' | sed 's/.*\.zone\.//')

CF_DOMAIN=$(curl -fsSL -X GET "$CF_API_BASE/zones/$CF_ZONE_ID" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_SERVICE_DOMAIN=$(curl -fsSL -X GET "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/workers/domains" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -B3 '"hostname": "'"$SERVICE_DOMAIN"'"' | \
    grep '"id"' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_DOMAIN" ]; then
    echo "Error: Unable to retrieve Cloudflare domain."
    exit 1
fi

if [ -z "$CF_ZONE_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare zone ID."
    exit 1
fi

if [ -z "$CF_ACCOUNT_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare account ID."
    exit 1
fi

SERVICE_DOMAIN="$SERVICE_NAME.$CF_DOMAIN"
SERVICE_URL="https://$SERVICE_DOMAIN"
WORKER_META='{"main_module":"worker.js","placement":{"mode":"smart"}}'
BOUNDARY="----formdata"

echo "✅ Domain: $CF_DOMAIN"
echo "✅ Zone ID: $CF_ZONE_ID"
echo "✅ Account ID: $CF_ACCOUNT_ID"
echo "📝 Service name: $SERVICE_NAME"
echo "🌐 Service domain: $SERVICE_DOMAIN"
echo "📤 Creating worker script..."

form_data=$(cat <<EOF
--$BOUNDARY
Content-Disposition: form-data; name="metadata"; filename="worker-metadata.json"
Content-Type: application/json

$WORKER_META
--$BOUNDARY
Content-Disposition: form-data; name="script"; filename="worker.js"
Content-Type: application/javascript+module

$WORKER_CONETENT
--$BOUNDARY--
EOF
)

UPLOAD_RESPONSE=$(curl -fsSL -X PUT \
    "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/workers/scripts/$SERVICE_NAME" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: multipart/form-data; boundary=$BOUNDARY" \
    --data-binary "$form_data")

if ! echo "$UPLOAD_RESPONSE" | grep -q '"success": true'; then
    echo "❌ Failed to create worker"
    echo "Response: $UPLOAD_RESPONSE"
    exit 1
fi

echo "✅ Worker script created"

echo "📝 Setting up custom service domain route..."
if [ -z "$CF_SERVICE_DOMAIN" ]; then
    DOMAIN_RESPONSE=$(curl -fsSL -X PUT \
        "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/workers/domains" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "environment": "production",
            "hostname": "'"$SERVICE_DOMAIN"'",
            "service": "'"$SERVICE_NAME"'",
            "zone_id": "'"$CF_ZONE_ID"'"
        }')
    
    if echo "$DOMAIN_RESPONSE" | grep -q '"success": true'; then
        echo "✅ Custom domain attached: $SERVICE_URL"
    else
        echo "⚠️  Failed to attach custom domain: $DOMAIN_RESPONSE"
    fi
else
    echo "✅ Custom domain already attached: $SERVICE_URL"
fi