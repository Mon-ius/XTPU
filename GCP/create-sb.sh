#!/bin/dash

sudo apt-get -qq update && sudo apt-get -qq install gnupg2 curl jq

SAGER_NET="https://sing-box.app/gpg.key"
curl -fsSL "$SAGER_NET" | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sagernet.gpg
echo "deb https://deb.sagernet.org * *" | sudo tee /etc/apt/sources.list.d/sagernet.list
sudo apt-get update && sudo apt-get install sing-box

_CF_ZONE="sub"
_CF_DOMAIN="example.com"
_CF_TOKEN="jdqgyu2g3u1309i09i0"

CF_TOKEN="${1:-$_CF_TOKEN}"
CF_DOMAIN="${2:-$_CF_DOMAIN}"
CF_ZONE="${3:-$_CF_ZONE}"

curl -fsSL bit.ly/new-gcp-dns | sh -s -- "$CF_TOKEN" "$CF_DOMAIN" "$CF_ZONE"

OBFS="$(echo "$USER-$CF_TOKEN" | base64)"
# echo "$USER-$CF_TOKEN"
# echo "$OBFS"
cat <<EOF | sudo tee /etc/sing-box/config.json
{
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        }
    ],
    "inbounds": [
        {   
            "sniff": true,
            "sniff_override_destination": true,
            "type": "hysteria2",
            "listen": "::",
            "listen_port": 443,
            "up_mbps": 10000,
            "down_mbps": 10000,
            "obfs": {
                "type": "salamander",
                "password": "$OBFS"
            },
            "users": [
                {
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
    ]
}
EOF

sudo systemctl enable sing-box
sudo systemctl daemon-reload
sudo systemctl restart sing-box