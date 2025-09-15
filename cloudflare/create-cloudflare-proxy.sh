#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token> [service-name] [service-endpoint]"
    echo ""
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== my-service example.com"
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'
_SERVICE_NAME="worker-$(date +%Y%m%d)-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 8)"
_SERVICE_ENDPOINT='example.com'


CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
SERVICE_NAME="${2:-$_SERVICE_NAME}"
SERVICE_ENDPOINT="${3:-$_SERVICE_ENDPOINT}"

WORKER_CONETENT=$(cat <<EOF
export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        url.host = '$SERVICE_ENDPOINT';
        return fetch(new Request(url, request))
    }
};
EOF
)

curl -fsSL bit.ly/create-cloudflare-worker | sh -s -- "$CF_TOKEN_BASE64" "$SERVICE_NAME" "$WORKER_CONETENT"
