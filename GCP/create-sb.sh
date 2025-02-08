#!/bin/dash

sudo apt-get -qq update && sudo apt-get -qq install gnupg2 curl jq
SAGER_NET="https://sing-box.app/gpg.key"
curl -fsSL "$SAGER_NET" | sudo gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/sagernet.gpg
echo "deb https://deb.sagernet.org * *" | sudo tee /etc/apt/sources.list.d/sagernet.list
sudo apt-get update && sudo apt-get install sing-box

CF_TOKEN="${1:-$_CF_TOKEN}"
CF_DOMAIN="${2:-$_CF_DOMAIN}"
CF_ZONE="${3:-$_CF_ZONE}"

curl -fsSL bit.ly/new-gcp-dns | sh -s -- "$CF_TOKEN" "$CF_DOMAIN" "$CF_ZONE"

HY2_PART=$(cat <<EOF
        {
            "type": "hysteria2",
            "tag": "hy2-in",
            "listen": "::",
            "listen_port": 443,
            "up_mbps": 10000,
            "down_mbps": 10000,
            "users": [
                {
                    "name": "admin",
                    "password": "$CF_TOKEN"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "$CF_ZONE.$CF_DOMAIN",
                "acme": {
                    "domain": "$CF_ZONE.$CF_DOMAIN",
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

sudo tee /etc/sing-box/config.json > /dev/null << EOF
{
    "inbounds": [
$HY2_PART
    ]
}
EOF

sudo systemctl enable sing-box
sudo systemctl daemon-reload
sudo systemctl restart sing-box