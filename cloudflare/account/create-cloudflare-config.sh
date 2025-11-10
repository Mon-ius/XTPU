#!/bin/dash

set +e

_CF_TOKEN_BASE64="base64encodedtoken"
_CF_SERVICE="example"
_CF_DOMAIN="example.com"
_CF_IP="1.2.3.4"

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token> [service] [domain] [ip]"
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== example example.com 1.2.3.4"
    exit 1
fi

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_SERVICE="${2:-$_CF_SERVICE}"
CF_DOMAIN="${3:-$_CF_DOMAIN}"
CF_IP="${4:-$_CF_IP}"

echo "[INFO] Server Address: ${CF_SERVICE}.${CF_DOMAIN}" >&2
echo "[INFO] Server IP: $CF_IP" >&2
echo "[INFO] Service: $CF_SERVICE" >&2
echo "[INFO] Domain: $CF_DOMAIN" >&2
echo "" >&2

CONFIG_JSON=$(cat <<EOF
{
    "experimental": {
        "cache_file": {
            "enabled": true,
            "store_rdrc": true
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "remote",
                "type": "https",
                "server": "doh.opendns.com",
                "domain_resolver": "local",
                "detour": "Proxy"
            },
            {
                "tag": "local",
                "type": "udp",
                "server": "119.29.29.29"
            }
        ],
        "rules": [
            {
                "domain_suffix": [".com.cn", ".gov.cn", ".cn"],
                "server": "local",
                "action": "route"
            },
            {
                "rule_set": ["geosite-qcloud", "geosite-tencent"],
                "server": "local",
                "action": "route"
            },
            {
                "rule_set": ["geosite-geolocation-cn", "geosite-china-list"],
                "server": "local",
                "action": "route"
            },
            {
                "action": "route-options",
                "domain": [
                    "*"
                ],
                "rewrite_ttl": 64,
                "udp_connect": false,
                "udp_disable_domain_unmapping": false
            },
            {
                "type": "logical",
                "mode": "and",
                "rules": [
                    {
                        "rule_set": "geosite-geolocation-!cn",
                        "invert": true
                    },
                    {
                        "rule_set": "geoip-cn"
                    }
                ],
                "server": "remote",
                "client_subnet": "114.114.114.114/24"
            }
        ],
        "strategy": "ipv4_only",
        "final": "remote",
        "reverse_mapping": true,
        "disable_cache": false,
        "disable_expire": false
    },
    "inbounds": [
        {
            "type": "tun",
            "tag": "tun-in",
            "interface_name": "tun0",
            "address": [
                "172.19.0.0/30",
                "fdfe:dcba:9876::0/126"
            ],
            "mtu": 1500,
            "auto_route": true,
            "strict_route": true,
            "stack": "gvisor"
        }
    ],
    "outbounds": [
        {
            "tag": "direct-out",
            "type": "direct",
            "udp_fragment": true
        },
        {
            "tag": "Proxy",
            "outbounds": [
                "$CF_SERVICE",
                "direct-out"
            ],
            "interrupt_exist_connections": true,
            "default": "$CF_SERVICE",
            "type": "selector"
        },
        {
            "tag": "$CF_SERVICE",
            "type": "anytls",
            "server": "$CF_IP",
            "server_port": 443,
            "password": "$CF_TOKEN_BASE64",
            "idle_session_check_interval": "30s",
            "idle_session_timeout": "30s",
            "min_idle_session": 5,
            "tls": {
                "enabled": true,
                "server_name": "${CF_SERVICE}.${CF_DOMAIN}",
                "cipher_suites": [
                    "TLS_AES_128_GCM_SHA256",
                    "TLS_AES_256_GCM_SHA384",
                    "TLS_CHACHA20_POLY1305_SHA256"
                ],
                "alpn": [
                    "h3"
                ]
            }
        }
    ],
    "route": {
        "final": "Proxy",
        "auto_detect_interface": true,
        "default_domain_resolver": {
            "server": "local",
            "rewrite_ttl": 60
        },
        "rules": [
            {
                "inbound": "tun-in",
                "action": "sniff"
            },
            {
                "protocol": "dns",
                "action": "hijack-dns"
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
                "rule_set": ["geosite-qcloud", "geosite-tencent"],
                "outbound": "direct-out"
            },
            {
                "rule_set": ["geoip-cn", "geosite-geolocation-cn", "geosite-china-list"],
                "outbound": "direct-out"
            },
            {
                "rule_set": ["geosite-geolocation-!cn", "geosite-category-cas", "geosite-category-media"],
                "outbound": "Proxy"
            }
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
                "tag": "geosite-qcloud",
                "type": "remote",
                "format": "binary",
                "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-qcloud.srs",
                "download_detour": "direct-out"
            },
            {
                "tag": "geosite-tencent",
                "type": "remote",
                "format": "binary",
                "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-tencent.srs",
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
                "tag": "geosite-category-cas",
                "type": "remote",
                "format": "binary",
                "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-category-cas.srs",
                "download_detour": "direct-out"
            },
            {
                "tag": "geosite-category-media",
                "type": "remote",
                "format": "binary",
                "url": "https://testingcf.jsdelivr.net/gh/lyc8503/sing-box-rules@rule-set-geosite/geosite-category-media.srs",
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
            }
        ]
    }
}
EOF
)

echo "$CONFIG_JSON" | base64 -w 0 | tee "/tmp/${CF_SERVICE}.txt" > /dev/null