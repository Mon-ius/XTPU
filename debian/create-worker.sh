#!/bin/dash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <base64-encoded-cf-api-token> [service-name] [worker-file]"
    echo ""
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== my-service worker.js"
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'
_WORKER_FILE='worker.js'
_SERVICE_NAME="worker-$(date +%Y%m%d)-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 8)"

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
SERVICE_NAME="${2:-$_SERVICE_NAME}"
WORKER_FILE="${3:-$_WORKER_FILE}"
SERVICE_DOMAIN="$SERVICE_NAME.$CF_DOMAIN"
SERVICE_URL="https://$SERVICE_DOMAIN"
WORKER_META='{"main_module":"worker.js"}'
BOUNDARY="----formdata"

CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

if [ -f "$WORKER_FILE" ]; then
    script_content=$(cat "$WORKER_FILE")
else
    echo "⚠️  Worker file '$WORKER_FILE' not found. Using default worker..."
    script_content=$(cat <<EOF
export default {
    async fetch(request) {
        const url = new URL(request.url);
        return new Response(JSON.stringify({
            message: "Hello from Cloudflare Workers!",
            serviceName: "$SERVICE_NAME",
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
fi

echo "🔍 Fetching account information..."

CF_DOMAIN=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_ZONE_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_ACCOUNT_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/accounts" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_SERVICE_DOMAIN=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/domains" | \
    grep -B3 "\"hostname\": \"$SERVICE_DOMAIN\"" | grep '"id"' | cut -d'"' -f4 | head -n 1)


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

$script_content
--$BOUNDARY--
EOF
)

UPLOAD_RESPONSE=$(curl -fsSL -X PUT \
    "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/scripts/$SERVICE_NAME" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: multipart/form-data; boundary=$BOUNDARY" \
    --data-binary "$form_data")

if ! echo "$UPLOAD_RESPONSE" | grep -q '"success":true'; then
    echo "❌ Failed to create worker"
    echo "Response: $UPLOAD_RESPONSE"
    exit 1
fi

echo "✅ Worker script created"

echo "📝 Setting up custom service domain route..."
if [ -z "$CF_SERVICE_DOMAIN" ]; then
    DOMAIN_RESPONSE=$(curl -fsSL -X PUT \
        "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/domains" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "override_existing_dns_record": "true",
            "environment": "production",
            "hostname": "'"$SERVICE_DOMAIN"'",
            "zone_id": "'"$CF_ZONE_ID"'",
            "service": "'"$SERVICE_NAME"'"
        }')
    
    if echo "$DOMAIN_RESPONSE" | grep -q '"success": true'; then
        echo "✅ Custom domain attached"
    else
        echo "⚠️  Failed to attach custom domain: $DOMAIN_RESPONSE"
    fi
else
    echo "✅ Custom domain already attached"
fi


echo "📝 Setting up workers.dev access..."
subdomain_check=$(curl -fsSL "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/subdomain" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json")

EXISTING_SUBDOMAIN=$(echo "$subdomain_check" | grep -o '"subdomain": *"[^"]*' | cut -d'"' -f4)

if [ -n "$EXISTING_SUBDOMAIN" ] && [ "$EXISTING_SUBDOMAIN" != "null" ]; then
    DEV_RESPONSE=$(curl -fsSL -X POST \
        "https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/workers/scripts/$SERVICE_NAME/subdomain" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "enabled": true,
            "previews_enabled": true
        }')

    if echo "$DEV_RESPONSE" | grep -q '"success": true'; then
        WORKERS_DEV_URL="https://$SERVICE_NAME.$EXISTING_SUBDOMAIN.workers.dev"
        echo "✅ Workers.dev - $WORKERS_DEV_URL enabled"
    else
        echo "⚠️  Failed to enable workers.dev: $DEV_RESPONSE"
    fi
fi

echo ""
echo "🎉 Deployment complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Service Domain: $SERVICE_URL"
if [ -n "$WORKERS_DEV_URL" ]; then
    echo "Workers.dev:   $WORKERS_DEV_URL"
fi

echo ""
echo "🧪 Testing deployment..."
sleep 5

test_response=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL" 2>/dev/null || echo "000")

if [ "$test_response" = "200" ] || [ "$test_response" = "404" ] || [ "$test_response" = "401" ]; then
    echo "✅ Worker is responding (HTTP $test_response)"
else
    echo "⚠️  Worker may still be propagating (HTTP $test_response)"
    echo "   DNS propagation can take 1-2 minutes"
fi