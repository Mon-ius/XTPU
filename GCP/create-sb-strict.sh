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
    "dns": {
        "servers": [
            {
                "tag": "ND-h3",
                "address": "h3://dns.nextdns.io/x",
                "address_resolver": "dns-direct",
                "detour": "direct-out"
            },
            {
                "tag": "dns-direct",
                "address": "udp://223.5.5.5",
                "detour": "direct-out"
            }
        ],
        "strategy": "ipv4_only",
        "final": "ND-h3",
        "reverse_mapping": true,
        "disable_cache": false,
        "disable_expire": false
    },
    "route": {
        "rules": [
            {
                "inbound": "hy2-in",
                "action": "sniff",
                "sniffer": [
                    "dns",
                    "bittorrent",
                    "http",
                    "tls",
                    "quic",
                    "dtls"
                ]
            },
            {
                "protocol": "dns",
                "action": "hijack-dns"
            },
            {
                "ip_is_private": true,
                "action": "route",
                "outbound": "direct-out"
            },
            {
                "ip_cidr": [
                    "0.0.0.0/8",
                    "10.0.0.0/8",
                    "127.0.0.0/8",
                    "169.254.0.0/16",
                    "172.16.0.0/12",
                    "192.168.0.0/16",
                    "224.0.0.0/4",
                    "240.0.0.0/4",
                    "52.80.0.0/16"
                ],
                "action": "route",
                "outbound": "direct-out"
            }
        ],
        "auto_detect_interface": true,
        "final": "direct-out"
    },
    "inbounds": [
$HY2_PART
    ],
    "outbounds": [
        {
            "tag": "direct-out",
            "udp_fragment": true,
            "type": "direct"
        }
    ],
}
EOF

sudo systemctl enable sing-box
sudo systemctl daemon-reload
sudo systemctl restart sing-box