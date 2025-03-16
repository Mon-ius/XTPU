#!/bin/dash

_CF_ZONE="sub"
_CF_TOKEN="base64encodedtoken"

_WARP_SERVER=engage.cloudflareclient.com
_WARP_PORT=2408
_NET_PORT=9091

CF_TOKEN="${1:-$_CF_TOKEN}"
CF_ZONE="${2:-$_CF_ZONE}"
WARP_SERVER="${3:-$_WARP_SERVER}"
WARP_PORT="${4:-$_WARP_PORT}"

curl -fsSL bit.ly/new-gcp-dns | sh -s -- "$CF_TOKEN" "$CF_ZONE"
curl -fsSL bit.ly/create-sbox | sh

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
                        "api_token": "$(echo "$CF_TOKEN" | base64 -d)"
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
        "final": "WARP"
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