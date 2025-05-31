#!/bin/dash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token>"
    exit 1
fi

_CF_TOKEN_BASE64="base64encodedtoken"

if ! command -v cron >/dev/null 2>&1; then
    echo "[INFO] Installing cron..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y cron
    elif command -v yum >/dev/null 2>&1; then
        yum install -y cronie
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache dcron
    else
        echo "Error: Unable to install cron. Please install manually."
        exit 1
    fi
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl enable cron || systemctl enable crond
        systemctl start cron || systemctl start crond
    elif command -v service >/dev/null 2>&1; then
        service cron start || service crond start
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service dcron start
        rc-update add dcron default
    fi
fi

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)
NG_ACME=~/.acme.sh/acme.sh
NG_SSL=/etc/nginx/ssl

export CF_TOKEN="$CF_TOKEN"

CF_DOMAIN=$(curl -fsSL "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_Zone_ID=$(curl -fsSL "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

export CF_Zone_ID="$CF_Zone_ID"

if [ -z "$CF_DOMAIN" ]; then
    echo "Error: Unable to retrieve Cloudflare domain."
    exit 1
fi

if [ -z "$CF_Zone_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare zone ID."
    exit 1
fi

WILDCARD_DOMAIN="*.$CF_DOMAIN"
SSL_KEY="$NG_SSL/wildcard.$CF_DOMAIN.key"
SSL_FULL_CHAIN="$NG_SSL/wildcard.$CF_DOMAIN.pem"
SSL_DHPARAM="$NG_SSL/wildcard.$CF_DOMAIN.dpr"

echo "[INFO] Generating wildcard certificate for $WILDCARD_DOMAIN"

if [ ! -d "$NG_SSL" ]; then
    echo "[INFO] Creating SSL directory: $NG_SSL"
    mkdir -p $NG_SSL
fi

if [ ! -e $NG_ACME ]; then
    curl https://get.acme.sh | sh -s email="admin@$CF_DOMAIN"
fi

$NG_ACME --upgrade --auto-upgrade

$NG_ACME --issue -d "$CF_DOMAIN" -d "$WILDCARD_DOMAIN" --dns dns_cf -k ec-256

$NG_ACME --install-cert -d "$CF_DOMAIN" \
    --key-file       "$SSL_KEY"  \
    --fullchain-file "$SSL_FULL_CHAIN" \
    --dns dns_cf --ecc

openssl dhparam -dsaparam -out "$SSL_DHPARAM" 4096

$NG_ACME --install-cronjob

echo "[SUCCESS] Wildcard certificate generated successfully!"
echo "Certificate: $SSL_FULL_CHAIN"
echo "Private Key: $SSL_KEY"
echo "DH Parameters: $SSL_DHPARAM"