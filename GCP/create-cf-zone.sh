#!/bin/bash

_CF_ZONE="sub"
_CF_DOMAIN="example.com"
_CF_TOKEN="jdqgyu2g3u1309i09i0"

CF_TOKEN="${1:-$_CF_TOKEN}"
CF_DOMAIN="${2:-$_CF_DOMAIN}"
CF_ZONE="${3:-$_CF_ZONE}"

CF_IP=$(curl -s http://ipinfo.io/ip)
if [ -z "$CF_IP" ]; then
    echo "Error: Unable to retrieve external IP address. Please check your internet connection."
    exit 1
fi

echo "External IP: $CF_IP"

CF_ZONE_ID=$(curl -s -X GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones?name=$CF_DOMAIN" | grep -o '"id":"[^"]*"' | head -n 1 | awk -F: '{print $2}' | tr -d '"')

if [ -z "$CF_ZONE_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare zone ID for domain $CF_DOMAIN. Please check your API token and domain name."
    exit 1
fi

echo "Zone ID: $CF_ZONE_ID"

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -d '{
        "content": "'"${CF_IP}"'",
        "name": "'"${CF_ZONE}.${CF_DOMAIN}"'",
        "proxied": false,
        "type": "A",
        "comment": "",
        "tags": [],
        "ttl": 60
    }')

if [ "$RESPONSE" -eq 200 ]; then
    echo "Success: DNS record created for ${CF_ZONE}.${CF_DOMAIN} with IP ${CF_IP}."
else
    echo "Error: Failed to create DNS record. HTTP status code: $RESPONSE"
    exit 1
fi