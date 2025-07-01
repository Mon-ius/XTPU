#!/bin/dash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token> <service_name>"
    exit 1
fi

_CF_TOKEN_BASE64='base64encodedtoken'
_SERVICE_NAME='*'

if ! command -v crontab >/dev/null 2>&1; then
    echo "[INFO] Installing cron..."
    sudo apt-get update && sudo apt-get install -y cron
    sudo systemctl enable cron
    sudo systemctl start cron
fi

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
SERVICE_NAME="${2:-$_SERVICE_NAME}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)
NG_ACME=~/.acme.sh/acme.sh
NG_SSL=/etc/nginx/ssl

CF_DOMAIN=$(curl -fsSL "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)

CF_ZONE_ID=$(curl -fsSL "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" | \
    grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_DOMAIN" ]; then
    echo "Error: Unable to retrieve Cloudflare domain."
    exit 1
fi

if [ -z "$CF_ZONE_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare zone ID."
    exit 1
fi

export CF_Token="$CF_TOKEN"
export CF_Zone_ID="$CF_ZONE_ID"
FULL_DOMAIN="$SERVICE_NAME.$CF_DOMAIN"
SSL_KEY="$NG_SSL/$FULL_DOMAIN.key"
SSL_FULL_CHAIN="$NG_SSL/$FULL_DOMAIN.pem"
SSL_DHPARAM="$NG_SSL/$FULL_DOMAIN.dpr"

echo "[INFO] Generating wildcard certificate for $FULL_DOMAIN"

if [ ! -d "$NG_SSL" ]; then
    echo "[INFO] Creating SSL directory: $NG_SSL"
    sudo mkdir -p $NG_SSL
fi

sudo chown "$USER:$USER" $NG_SSL
sudo chown -R "$USER:$USER" $NG_SSL

if [ ! -e $NG_ACME ]; then
    curl https://get.acme.sh | sh -s email="admin@$CF_DOMAIN"
fi

if [ -e $NG_ACME ]; then
    $NG_ACME --upgrade --auto-upgrade
    $NG_ACME --issue -d "$FULL_DOMAIN" --server letsencrypt --dns dns_cf -k ec-256
    $NG_ACME --install-cert -d "$FULL_DOMAIN" \
        --key-file       "$SSL_KEY"  \
        --fullchain-file "$SSL_FULL_CHAIN" \
        --dns dns_cf --ecc
    openssl dhparam -dsaparam -out "$SSL_DHPARAM" 4096
    $NG_ACME --install-cronjob
fi

echo "[SUCCESS] Wildcard certificate generated successfully!"
echo "Certificate: $SSL_FULL_CHAIN"
echo "Private Key: $SSL_KEY"
echo "DH Parameters: $SSL_DHPARAM"