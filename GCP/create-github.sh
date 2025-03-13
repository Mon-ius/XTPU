#!/bin/dash

_CF_TOKEN="jdqgyu2g3u1309i09i0"
_GITHUB="github"

CF_TOKEN="${1:-$_CF_TOKEN}"
GITHUB="${2:-$_GITHUB}"


CF_ZONE_ID=$(curl -sX GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones" | grep -o '"id":"[^"]*"' | head -n 1 | awk -F: '{print $2}' | tr -d '"')
CF_DOMAIN=$(curl -sX GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones" | grep -o '"name":"[^"]*"' | head -n 1 | awk -F: '{print $2}' | tr -d '"')

RESPONSE=$(curl -sX POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -d '{
        "targets": [
            {
                "target": "url",
                "constraint": {
                    "operator": "matches",
                    "value": "'"${CF_DOMAIN}"'"
                }
            }
        ],
        "actions": [
            {
                "id": "forwarding_url",
                "value": {
                    "url": "https://github.com/'"${GITHUB}"'",
                    "status_code": 301
                }
            }
        ],
        "status": "active"
    }')

echo "$RESPONSE"