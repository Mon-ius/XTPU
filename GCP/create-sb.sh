#!/bin/dash

sudo apt-get -qq update && sudo apt-get -qq install gnupg2 curl jq
SAGER_NET="https://sing-box.app/gpg.key"
curl -fsSL "$SAGER_NET" | sudo gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/sagernet.gpg
echo "deb https://deb.sagernet.org * *" | sudo tee /etc/apt/sources.list.d/sagernet.list
sudo apt-get update && sudo apt-get install sing-box

_CF_ZONE="sub"
_CF_DOMAIN="example.com"
_CF_TOKEN="jdqgyu2g3u1309i09i0"
_WARP_SERVER=engage.cloudflareclient.com
_WARP_PORT=2408
_NET_PORT=9091

CF_TOKEN="${1:-$_CF_TOKEN}"
CF_DOMAIN="${2:-$_CF_DOMAIN}"
CF_ZONE="${3:-$_CF_ZONE}"
WARP_SERVER="${WARP_SERVER:-$_WARP_SERVER}"
WARP_PORT="${WARP_PORT:-$_WARP_PORT}"
NET_PORT="${NET_PORT:-$_NET_PORT}"

curl -fsSL bit.ly/new-gcp-dns | sh -s -- "$CF_TOKEN" "$CF_DOMAIN" "$CF_ZONE"

RESPONSE=$(curl -fsSL bit.ly/warp_socks | sh)
private_key=$(echo "$RESPONSE" | sed -n 's/.*"private_key":"\([^"]*\)".*/\1/p')
ipv4=$(echo "$RESPONSE" | sed -n 's/.*"v4":"\([^"]*\)".*/\1/p')
ipv6=$(echo "$RESPONSE" | sed -n 's/.*"v6":"\([^"]*\)".*/\1/p')
public_key=$(echo "$RESPONSE" | sed -n 's/.*"public_key":"\([^"]*\)".*/\1/p')
client_hex=$(echo "$RESPONSE" | grep -o '"client_id":"[^"]*' | cut -d'"' -f4 | base64 -d | od -t x1 -An | tr -d ' \n')
reserved_dec=$(echo "$client_hex" | awk '{printf "[%d, %d, %d]", "0x"substr($0,1,2), "0x"substr($0,3,2), "0x"substr($0,5,2)}')

WARP_PART=$(cat <<EOF
    "endpoints": [
        {
            "tag": "WARP",
            "type": "wireguard",
            "address": [
                "${ipv4}/32",
                "${ipv6}/128"
            ],
            "private_key": "$private_key",
            "peers": [
                {
                    "address": "$WARP_SERVER",
                    "port": $WARP_PORT,
                    "public_key": "$public_key",
                    "allowed_ips": [
                        "0.0.0.0/0"
                    ],
                    "persistent_keepalive_interval": 30,
                    "reserved": $reserved_dec
                }
            ],
            "mtu": 1408,
            "udp_fragment": true
        }
    ]
EOF
)

_DIRECT_PART=$(cat <<EOF
    "outbounds": [
        {
            "tag": "direct-out",
            "udp_fragment": true,
            "type": "direct"
        }
    ]
EOF
)

cat <<EOF | sudo tee /etc/sing-box/config.json
{
$WARP_PART,
    "inbounds": [
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
    ]
}
EOF

sudo systemctl enable sing-box
sudo systemctl daemon-reload
sudo systemctl restart sing-box