#!/bin/dash

set +e

export DEBIAN_FRONTEND=noninteractive
SAGER_NET="https://sing-box.app/gpg.key"
CF_API_BASE="https://api.cloudflare.com/client/v4"

_CF_TOKEN_BASE64="base64encodedtoken"
_CF_SERVICE="example"

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token> [service]"
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== example"
    exit 1
fi

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y gnupg2 curl jq

curl -fsSL "$SAGER_NET" | sudo -E gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/sagernet.gpg
echo "deb https://deb.sagernet.org * *" | sudo -E tee /etc/apt/sources.list.d/sagernet.list

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y sing-box

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_SERVICE="${2:-$_CF_SERVICE}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

CF_IP=$(curl -fsSL https://ipinfo.io/ip)
CF_ACCOUNT_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_TOKEN_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/verify" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_ZONE_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/$CF_TOKEN_ID" | grep -o 'com.cloudflare.api.account.zone.[^"]*' | sed 's/.*\.zone\.//')
CF_DOMAIN=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/zones/$CF_ZONE_ID" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)
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
    echo "Error: Unable to retrieve Cloudflare zone ID for domain $CF_DOMAIN. Please check your API token with [Account API Tokens Read] setting and domain name."
    exit 1
fi

echo "[INFO] External IP: CF_IP=$CF_IP"
echo "[INFO] Domain: CF_DOMAIN=$CF_DOMAIN"
echo "[INFO] Zone ID: CF_ZONE_ID=$CF_ZONE_ID"
echo "[INFO] Service: CF_SERVICE=$CF_SERVICE"
echo "[INFO] Record ID: CF_RECORD=$CF_RECORD"

DNS_PAYLOAD='{
    "type": "A",
    "name": "'"${CF_SERVICE}.${CF_DOMAIN}"'",
    "content": "'"${CF_IP}"'",
    "proxied": false
}'

CONFIG_PAYLOAD=$(cat <<EOF
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "::",
            "listen_port": 443,
            "users": [
                {
                    "flow": "xtls-rprx-vision",
                    "uuid": "$(echo "$CF_TOKEN_BASE64" | sha1sum | cut -c1-32 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\).*$/\1-\2-\3-\4-\5/')"
                },
                {
                    "flow": "xtls-rprx-vision",
                    "uuid": "$(echo "user-$CF_TOKEN_BASE64" | sha1sum | cut -c1-32 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\).*$/\1-\2-\3-\4-\5/')"
                },
                {
                    "flow": "xtls-rprx-vision",
                    "uuid": "$(echo "admin-$CF_TOKEN_BASE64" | sha1sum | cut -c1-32 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\).*$/\1-\2-\3-\4-\5/')"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$CF_SERVICE.$CF_DOMAIN",
                "acme": {
                    "domain": "$CF_SERVICE.$CF_DOMAIN",
                    "email": "admin@$CF_DOMAIN",
                    "dns01_challenge": {
                        "provider": "cloudflare",
                        "api_token": "$CF_TOKEN"
                    }
                },
                "alpn": [
                    "h3"
                ]
            }
        }
EOF
)

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
    echo "[SUCCESS] A record for ${CF_SERVICE}.${CF_DOMAIN} has been updated with IP ${CF_IP}."

sudo tee /etc/sing-box/config.json > /dev/null << EOF
{
    "inbounds": [
$CONFIG_PAYLOAD
    ]
}

sudo systemctl daemon-reload
sudo systemctl enable sing-box
sudo systemctl restart sing-box
EOF
else
    echo "[ERROR] Failed to create or modify A record for ${CF_SERVICE}.${CF_DOMAIN}. HTTP status code: $RESPONSE"
    exit 1
fi



# curl -fsSL https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/cloudflare/account/create-cloudflare-token.sh | sh -s -- root_token
# curl -fsSL https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/cloudflare/account/create-cloudflare-dns.sh | sh -s -- token service