#!/bin/dash

_CF_ZONE="sub"
_CF_TOKEN_BASE64="base64encodedtoken"

_WARP_SERVER=engage.cloudflareclient.com
_WARP_PORT=2408
_NET_PORT=9091

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_ZONE="${2:-$_CF_ZONE}"
WARP_SERVER="${3:-$_WARP_SERVER}"
WARP_PORT="${4:-$_WARP_PORT}"

CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)
curl -fsSL bit.ly/create-sbox | sh
curl -fsSL bit.ly/new-gcp-dns | sh -s -- "$CF_TOKEN_BASE64" "$CF_ZONE"

CF_DOMAIN=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)

RESPONSE=$(curl -fsSL bit.ly/warp_socks | sh)
private_key=$(echo "$RESPONSE" | sed -n 's/.*"private_key":"\([^"]*\)".*/\1/p')
ipv4=$(echo "$RESPONSE" | sed -n 's/.*"v4":"\([^"]*\)".*/\1/p')
ipv6=$(echo "$RESPONSE" | sed -n 's/.*"v6":"\([^"]*\)".*/\1/p')
public_key=$(echo "$RESPONSE" | sed -n 's/.*"public_key":"\([^"]*\)".*/\1/p')
client_hex=$(echo "$RESPONSE" | grep -o '"client_id":"[^"]*' | cut -d'"' -f4 | base64 -d | od -t x1 -An | tr -d ' \n')
reserved_dec=$(echo "$client_hex" | awk '{printf "[%d, %d, %d]", "0x"substr($0,1,2), "0x"substr($0,3,2), "0x"substr($0,5,2)}')

# OBFS="$(echo "$USER-$CF_TOKEN" | base64)"

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
                    "password": "$CF_TOKEN_BASE64"
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
        "final": "WARP"
        "auto_detect_interface": true,
        "rules": [
            {
                "inbound": "hy2-in",
                "action": "sniff",
            },
            {
                "protocol": ["quic", "BitTorrent"],
                "action": "reject"
            },
            {
                "ip_is_private": true,
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
                    "52.80.0.0/16",
                    "112.95.0.0/16"
                ],
                "outbound": "direct-out"
            },
            {
                "domain_suffix": [".com.cn", ".gov.cn", ".cn"],
                "outbound": "direct-out"
            },
            {
                "rule_set": ["geoip-cn", "geosite-geolocation-cn", "geosite-china-list"],
                "outbound": "direct-out"
            },
        ],
    "rule_set": [
        {
            "tag": "geosite-china-list",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-china-list.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-geolocation-cn",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-geolocation-cn.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-geolocation-!cn",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-geolocation-!cn.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-category-ads-all",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-category-ads-all.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-youtube",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-youtube.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-google",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-google.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-github",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-github.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-reddit",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-reddit.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-category-ai",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-category-ai-!cn.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-facebook",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-facebook.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-cloudflare",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-cloudflare.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-discord",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-discord.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-tiktok",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-tiktok.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-disney",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-disney.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-hbo",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-hbo.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-primevideo",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-primevideo.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geosite-netflix",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-netflix.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geoip-netflix",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geoip/geoip-netflix.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geoip-google",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geoip/geoip-google.srs",
            "download_detour": "direct-out"
        },
        {
            "tag": "geoip-cn",
            "type": "remote",
            "format": "binary",
            "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geoip/geoip-cn.srs",
            "download_detour": "direct-out"
        }]
    },
    "inbounds": [
$HY2_PART
    ],
$WARP_PART,
    "outbounds": [
        {
            "tag": "direct-out",
            "type": "direct",
            "udp_fragment": true
        }
    ]
}
EOF

sudo tee /etc/systemd/system/update-sbox.service > /dev/null << EOF
[Unit]
Description=Check for sing-box updates and reboot if necessary
After=network-online.target nss-lookup.target
Wants=network-online.target nss-lookup.target

[Service]
Type=oneshot
Environment="DEBIAN_FRONTEND=noninteractive"
ExecStart=/bin/dash -c 'curl -fsSL https://bit.ly/create-sbox | bash'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/update-sbox.timer > /dev/null << EOF
[Unit]
Description=Run sing-box update check periodically

[Timer]
OnBootSec=15min
OnUnitActiveSec=24h
RandomizedDelaySec=1800

[Install]
WantedBy=timers.target

EOF

sudo systemctl daemon-reload
sudo systemctl enable sing-box
sudo systemctl restart sing-box
sudo systemctl disable update-sbox.timer
sudo systemctl disable update-sbox
sudo systemctl stop update-sbox.timer
sudo systemctl stop update-sbox
sudo systemctl enable update-sbox.timer
sudo systemctl restart update-sbox.timer