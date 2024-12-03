#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0  <remote> <passwd>"
    exit 1
fi

REMOTE="$1"
PASSWD="$2"
SAGER_NET="https://sing-box.app/gpg.key"
curl -fsSL "$SAGER_NET" | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/sagernet.gpg
echo "deb https://deb.sagernet.org * *" | sudo tee /etc/apt/sources.list.d/sagernet.list
sudo apt-get update && sudo apt-get install sing-box

sudo rm -rf /etc/apt/sources.list.d/sagernet.list
CONFIG=$(cat <<EOF
{
    "log": {
        "disabled": false,
        "level": "error",
        "timestamp": true
    },
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "cache.db",
            "cache_id": "v1",
            "store_fakeip": true
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "google",
                "address": "tls://8.8.8.8",
                "detour": "Proxy"
            },
            {
                "tag": "fallback",
                "address": "8.8.8.8",
                "address_resolver": "google",
                "detour": "Proxy"
            },
            {
                "tag": "local-dns",
                "address": "223.5.5.5",
                "detour": "direct"
            },
            {
                "tag": "block-dns",
                "address": "rcode://success"
            }
        ],
        "rules": [
            {
                "outbound": "any",
                "server": "local-dns"
            },
            {
                "rule_set": [
                    "Youtube0"
                ],
                "server": "fallback"
            },
            {
                "rule_set": [
                    "Telegram1"
                ],
                "server": "fallback"
            },
            {
                "rule_set": [
                    "Github0"
                ],
                "server": "fallback"
            },
            {
                "rule_set": [
                    "Openai0"
                ],
                "server": "fallback"
            },
            {
                "rule_set": [
                    "Netflix0"
                ],
                "server": "fallback"
            },
            {
                "rule_set": [
                    "Google0"
                ],
                "server": "fallback"
            },
            {
                "rule_set": [
                    "Direct1"
                ],
                "server": "local-dns"
            },
            {
                "query_type": [
                    "A"
                ],
                "rewrite_ttl": 1,
                "server": "fallback"
            }
        ],
        "strategy": "ipv4_only"
    },
    "inbounds": [
        {
            "type": "tun",
            "inet4_address": "172.19.0.1/30",
            "inet6_address": "fdfe:dcba:9876::1/126",
            "stack": "gvisor",
            "sniff": true,
            "auto_route": true,
            "sniff_override_destination": true,
            "strict_route": true,
            "gso": false
        }
    ],
    "route": {
        "rule_set": [
            {
                "type": "remote",
                "format": "binary",
                "download_detour": "Proxy",
                "tag": "Youtube0",
                "url": "https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geosite/youtube.srs"
            },
            {
                "type": "remote",
                "format": "binary",
                "download_detour": "Proxy",
                "tag": "Telegram0",
                "url": "https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geoip/telegram.srs"
            },
            {
                "type": "remote",
                "format": "binary",
                "download_detour": "Proxy",
                "tag": "Telegram1",
                "url": "https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geosite/telegram.srs"
            },
            {
                "type": "remote",
                "format": "binary",
                "download_detour": "Proxy",
                "tag": "Github0",
                "url": "https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geosite/github.srs"
            },
            {
                "type": "remote",
                "format": "binary",
                "download_detour": "Proxy",
                "tag": "Openai0",
                "url": "https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geosite/openai.srs"
            },
            {
                "type": "remote",
                "format": "binary",
                "download_detour": "Proxy",
                "tag": "Netflix0",
                "url": "https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geosite/netflix.srs"
            },
            {
                "type": "remote",
                "format": "binary",
                "download_detour": "Proxy",
                "tag": "Netflix1",
                "url": "https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo-lite/geoip/netflix.srs"
            },
            {
                "type": "remote",
                "format": "binary",
                "download_detour": "Proxy",
                "tag": "Google0",
                "url": "https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geosite/google.srs"
            },
            {
                "type": "remote",
                "format": "binary",
                "download_detour": "Proxy",
                "tag": "Direct0",
                "url": "https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geoip/cn.srs"
            },
            {
                "type": "remote",
                "format": "binary",
                "download_detour": "Proxy",
                "tag": "Direct1",
                "url": "https://github.com/MetaCubeX/meta-rules-dat/raw/sing/geo/geosite/cn.srs"
            }
        ],
        "rules": [
            {
                "protocol": "dns",
                "outbound": "dns-out"
            },
            {
                "port": 53,
                "outbound": "dns-out"
            },
            {
                "type": "logical",
                "mode": "or",
                "rules": [
                    {
                        "port": 853
                    },
                    {
                        "network": "udp",
                        "port": 443
                    },
                    {
                        "protocol": "stun"
                    }
                ],
                "outbound": "block"
            },
            {
                "rule_set": [
                    "Youtube0"
                ],
                "outbound": "Youtube"
            },
            {
                "rule_set": [
                    "Telegram0",
                    "Telegram1"
                ],
                "outbound": "Telegram"
            },
            {
                "rule_set": [
                    "Github0"
                ],
                "outbound": "Github"
            },
            {
                "rule_set": [
                    "Openai0"
                ],
                "outbound": "Openai"
            },
            {
                "rule_set": [
                    "Netflix0",
                    "Netflix1"
                ],
                "outbound": "Netflix"
            },
            {
                "rule_set": [
                    "Google0"
                ],
                "outbound": "Google"
            },
            {
                "rule_set": [
                    "Direct0",
                    "Direct1"
                ],
                "outbound": "direct"
            },
            {
                "ip_is_private": true,
                "outbound": "direct"
            }
        ],
        "auto_detect_interface": true,
        "final": "Proxy"
    },
    "outbounds": [
        {
            "tag": "Youtube",
            "outbounds": [
                "Proxy"
            ],
            "interrupt_exist_connections": true,
            "type": "selector"
        },
        {
            "tag": "Telegram",
            "outbounds": [
                "Proxy"
            ],
            "interrupt_exist_connections": true,
            "type": "selector"
        },
        {
            "tag": "Github",
            "outbounds": [
                "Proxy"
            ],
            "interrupt_exist_connections": true,
            "type": "selector"
        },
        {
            "tag": "Openai",
            "outbounds": [
                "Proxy"
            ],
            "interrupt_exist_connections": true,
            "type": "selector"
        },
        {
            "tag": "Netflix",
            "outbounds": [
                "Proxy"
            ],
            "interrupt_exist_connections": true,
            "type": "selector"
        },
        {
            "tag": "Google",
            "outbounds": [
                "Proxy"
            ],
            "interrupt_exist_connections": true,
            "type": "selector"
        },
        {
            "type": "direct",
            "tag": "direct"
        },
        {
            "type": "dns",
            "tag": "dns-out"
        },
        {
            "type": "block",
            "tag": "block"
        },
        {
            "tag": "Proxy",
            "type": "hysteria2",
            "server": "$REMOTE",
            "server_port": 443,
            "up_mbps": 1000,
            "down_mbps": 1000,
            "password": "$PASSWD",
            "connect_timeout": "5s",
            "tcp_fast_open": true,
            "tls": {
                "enabled": true,
                "server_name": "$REMOTE",
                "alpn": [
                    "h3"
                ]
            }
        }
    ]
}
EOF
)

echo "$CONFIG" | sudo tee /etc/sing-box/config.json
sudo systemctl daemon-reload
sudo systemctl enable sing-box
sudo systemctl restart sing-box

curl -fsSL "https://www.cloudflare.com/cdn-cgi/trace"