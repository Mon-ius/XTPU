#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token>"
    echo ""
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg=="
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
SERVICE_NAME="gemini-$(date +%Y%m%d)-$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 8)"
SERVICE_ENDPOINT='generativelanguage.googleapis.com'

curl -fsSL https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/worker/create-cloudflare-proxy.sh | sh -s -- "$CF_TOKEN_BASE64" "$SERVICE_NAME" "$SERVICE_ENDPOINT"

