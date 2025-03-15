#!/bin/dash

_CF_ZONE="sub"
_CF_DOMAIN="example.com"
_CF_TOKEN="jdqgyu2g3u1309i09i0"
_CF_NUM=0

CF_TOKEN="${1:-$_CF_TOKEN}"
CF_DOMAIN="${2:-$_CF_DOMAIN}"
CF_ZONE="${3:-$_CF_ZONE}"
CF_NUM="${4:-$_CF_NUM}"

CF_IP=$(curl -s http://ipinfo.io/ip)
if [ -z "$CF_IP" ]; then
    echo "Error: Unable to retrieve external IP address. Please check your internet connection."
    exit 1
fi

echo "External IP: $CF_IP, $CF_TOKEN, $CF_DOMAIN, $CF_ZONE"

CF_ZONE_ID=$(curl -s -X GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones?name=$CF_DOMAIN" | grep -o '"id":"[^"]*"' | head -n 1 | awk -F: '{print $2}' | tr -d '"')

if [ -z "$CF_ZONE_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare zone ID for domain $CF_DOMAIN. Please check your API token and domain name."
    exit 1
fi

echo "Zone ID: $CF_ZONE_ID"

DNS_RECORD=$(curl -s -X GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${CF_ZONE}.${CF_DOMAIN}" | grep -o '"id":"[^"]*"' | head -n 1 | awk -F: '{print $2}' | tr -d '"')

if [ -z "$DNS_RECORD" ]; then
    echo "DNS record not found. Creating a new DNS record..."
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
else
    echo "DNS record found. Modifying the existing DNS record..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${DNS_RECORD}" \
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
fi

if [ "$RESPONSE" -eq 200 ]; then
    echo "Success: A record for ${CF_ZONE}.${CF_DOMAIN} has been updated with IP ${CF_IP}."
else
    echo "Error: Failed to create or modify A record for ${CF_ZONE}.${CF_DOMAIN}. HTTP status code: $RESPONSE"
    exit 1
fi

case "$CF_NUM" in
    ''|*[!0-9]*) 
        echo "Invalid value for CF_NUM: $CF_NUM. Please provide a valid non-negative integer."
        exit 1
        ;;
    *)
        i=0
        while [ $i -lt "$CF_NUM" ]; do
            DNS_RECORD_ID=$(curl -s -X GET -H "Authorization: Bearer $CF_TOKEN" \
                "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${i}.${CF_ZONE}.${CF_DOMAIN}&type=CNAME" \
                | grep -o '"id":"[^"]*"' | head -n 1 | awk -F: '{print $2}' | tr -d '"')
            if [ -z "$DNS_RECORD_ID" ]; then
                echo "CNAME record not found for ${i}.${CF_ZONE}.${CF_DOMAIN}. Creating a new CNAME record..."
                RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer ${CF_TOKEN}" \
                    -d '{
                        "type": "CNAME",
                        "name": "'"${i}.${CF_ZONE}.${CF_DOMAIN}"'",
                        "content": "'"${CF_ZONE}.${CF_DOMAIN}"'",
                        "proxied": false,
                        "ttl": 60
                    }')
            else
                echo "CNAME record found for ${i}.${CF_ZONE}.${CF_DOMAIN}. Modifying the existing CNAME record..."
                RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${DNS_RECORD_ID}" \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer ${CF_TOKEN}" \
                    -d '{
                        "type": "CNAME",
                        "name": "'"${i}.${CF_ZONE}.${CF_DOMAIN}"'",
                        "content": "'"${CF_ZONE}.${CF_DOMAIN}"'",
                        "proxied": false,
                        "ttl": 60
                    }')
            fi

            if [ "$RESPONSE" -eq 200 ]; then
                echo "Success: CNAME record for ${i}.${CF_ZONE}.${CF_DOMAIN} has been updated to point to ${CF_ZONE}.${CF_DOMAIN}."
                i=$((i + 1))
            else
                echo "Error: Failed to create or modify CNAME record for ${i}.${CF_ZONE}.${CF_DOMAIN}. HTTP status code: $RESPONSE"
                break
            fi
        done
        ;;
esac