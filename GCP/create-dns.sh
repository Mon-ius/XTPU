#!/bin/dash

set +e

CF_API_BASE="https://api.cloudflare.com/client/v4"

_CF_TOKEN_BASE64="base64encodedtoken"
_CF_SERVICE="example"

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token> [service]"
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== example"
    exit 1
fi

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_SERVICE="${2:-$_CF_SERVICE}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

CF_IP=$(curl -fsSL https://ipinfo.io/ip)
CF_DOMAIN=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/zones" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_ZONE_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/zones" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_RECORD=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/zones/${CF_ZONE_ID}/dns_records?name=${CF_SERVICE}.${CF_DOMAIN}" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_IP" ]; then
    echo "Error: Unable to retrieve external IP address. Please check your internet connection."
    exit 1
fi

if [ -z "$CF_DOMAIN" ]; then
    echo "Error: Unable to retrieve domain. Please check your API token."
    exit 1
fi

if [ -z "$CF_ZONE_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare zone ID for domain $CF_DOMAIN. Please check your API token and domain name."
    exit 1
fi

echo "External IP: $CF_IP, $CF_TOKEN, $CF_DOMAIN, $CF_RECORD"

DNS_PAYLOAD='{
    "type": "A",
    "name": "'"${CF_SERVICE}.${CF_DOMAIN}"'",
    "content": "'"${CF_IP}"'",
    "proxied": false
}'

if [ -z "$CF_RECORD" ]; then
    echo "[INFO] DNS record not found. Creating a new DNS record..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$CF_API_BASE/zones/${CF_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$DNS_PAYLOAD")
else
    echo "[INFO] DNS record found. Modifying the existing DNS record..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$CF_API_BASE/zones/${CF_ZONE_ID}/dns_records/${CF_RECORD}" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$DNS_PAYLOAD")
fi

if [ "$RESPONSE" -eq 200 ]; then
    echo "Success: A record for ${CF_SERVICE}.${CF_DOMAIN} has been updated with IP ${CF_IP}."
else
    echo "Error: Failed to create or modify A record for ${CF_SERVICE}.${CF_DOMAIN}. HTTP status code: $RESPONSE"
    exit 1
fi