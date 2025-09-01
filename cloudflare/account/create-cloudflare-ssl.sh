#!/bin/dash

set +e

CF_API_BASE="https://api.cloudflare.com/client/v4"
_CF_TOKEN_BASE64="base64encodedtoken"
_CF_SERVICE="*"

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token> [service]"
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== subdomain"
    echo "  $0 eW91ci10b2tlbg== '*' (for wildcard)"
    exit 1
fi

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_SERVICE="${2:-$_CF_SERVICE}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

NG_ACME=~/.acme.sh/acme.sh
NG_SSL=/etc/nginx/ssl

CF_ACCOUNT_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_TOKEN_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/verify" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_ZONE_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/$CF_TOKEN_ID" | grep -o 'com.cloudflare.api.account.zone.[^"]*' | sed 's/.*\.zone\.//')
CF_DOMAIN=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/zones/$CF_ZONE_ID" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_DOMAIN" ]; then
    echo "[ERROR] Unable to retrieve domain. Please check your API token."
    exit 1
fi

if [ -z "$CF_ZONE_ID" ]; then
    echo "[ERROR] Unable to retrieve Cloudflare zone ID for domain $CF_DOMAIN. Please check your API token with [Account API Tokens Read] setting and domain name."
    exit 1
fi

export CF_Token="$CF_TOKEN"
export CF_Zone_ID="$CF_ZONE_ID"

if [ "$CF_SERVICE" = "*" ]; then
    FULL_DOMAIN="*.$CF_DOMAIN"
    SSL_BASE="wildcard.$CF_DOMAIN"
else
    FULL_DOMAIN="$CF_SERVICE.$CF_DOMAIN"
    SSL_BASE="$FULL_DOMAIN"
fi

SSL_KEY="$NG_SSL/$SSL_BASE.key"
SSL_FULL_CHAIN="$NG_SSL/$SSL_BASE.pem"
SSL_DHPARAM="$NG_SSL/$SSL_BASE.dpr"

echo "[INFO] Domain: CF_DOMAIN=$CF_DOMAIN"
echo "[INFO] Zone ID: CF_ZONE_ID=$CF_ZONE_ID"
echo "[INFO] Service: CF_SERVICE=$CF_SERVICE"
echo "[INFO] Certificate Domain: FULL_DOMAIN=$FULL_DOMAIN"
echo "[INFO] SSL Base Name: SSL_BASE=$SSL_BASE"

if [ ! -d "$NG_SSL" ]; then
    echo "[INFO] Creating SSL directory: $NG_SSL"
    sudo mkdir -p $NG_SSL
fi

sudo chown "$USER:$USER" $NG_SSL
sudo chown -R "$USER:$USER" $NG_SSL

if [ ! -e $NG_ACME ]; then
    echo "[INFO] Installing acme.sh..."
    curl https://get.acme.sh | sh -s email="admin@$CF_DOMAIN"
    if [ ! -e $NG_ACME ]; then
        echo "[ERROR] Failed to install acme.sh"
        exit 1
    fi
fi

echo "[INFO] Updating acme.sh..."
$NG_ACME --upgrade --auto-upgrade

echo "[INFO] Issuing certificate for $FULL_DOMAIN..."
ISSUE_RESPONSE=$($NG_ACME --issue -d "$FULL_DOMAIN" --server letsencrypt --dns dns_cf -k ec-256 2>&1)
ISSUE_CODE=$?

if [ $ISSUE_CODE -ne 0 ]; then
    if echo "$ISSUE_RESPONSE" | grep -q "already exists"; then
        echo "[INFO] Certificate already exists, proceeding with installation..."
    else
        echo "[ERROR] Failed to issue certificate: $ISSUE_RESPONSE"
        exit 1
    fi
fi

echo "[INFO] Installing certificate..."
INSTALL_RESPONSE=$($NG_ACME --install-cert -d "$FULL_DOMAIN" \
    --key-file       "$SSL_KEY" \
    --fullchain-file "$SSL_FULL_CHAIN" \
    --dns dns_cf --ecc 2>&1)
INSTALL_CODE=$?

if [ $INSTALL_CODE -ne 0 ]; then
    echo "[ERROR] Failed to install certificate: $INSTALL_RESPONSE"
    exit 1
fi

if [ ! -f "$SSL_DHPARAM" ]; then
    echo "[INFO] Generating DH parameters (this may take a while)..."
    openssl dhparam -dsaparam -out "$SSL_DHPARAM" 4096
    if [ $? -ne 0 ]; then
        echo "[ERROR] Failed to generate DH parameters"
        exit 1
    fi
else
    echo "[INFO] DH parameters already exist at $SSL_DHPARAM"
fi

echo "[INFO] Installing cronjob for auto-renewal..."
$NG_ACME --install-cronjob

echo "[SUCCESS] Certificate setup completed successfully!"
echo "Certificate: $SSL_FULL_CHAIN"
echo "Private Key: $SSL_KEY"
echo "DH Parameters: $SSL_DHPARAM"
echo ""
echo "Next steps:"
echo "1. Configure your nginx server block to use these certificates"
echo "2. Test your SSL configuration at: https://www.ssllabs.com/ssltest/"
echo "3. Verify auto-renewal with: $NG_ACME --list"