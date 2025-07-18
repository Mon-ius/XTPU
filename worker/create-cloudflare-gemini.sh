#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token>"
    echo ""
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== my-service"
    exit 1
fi

SERVICE_NAME="gemini"
SERVICE_ENDPOINT='generativelanguage.googleapis.com'