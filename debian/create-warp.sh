#!/bin/dash

# PRI='8BHIpadVAABzP/UiSzbv87tZTYD4BoZOikWYpH+YI20='
# PUB='eMsoIXGCylyloO2MlCVEK8wO/ZWkzPEjx7pur3nJ8Hc='

KEY=$(openssl genpkey -algorithm X25519)
PRI=$(echo "$KEY" | openssl pkey -outform DER | tail -c 32 | base64)
PUB=$(echo "$KEY" | openssl pkey -pubout -outform DER | tail -c 32 | base64)

WARP_API="https://api.cloudflareclient.com/v0a2077/reg"
RESPONSE=$(curl -sX POST "$WARP_API" \
    -H "Content-Type: application/json" \
    -H 'user-agent: okhttp/4.12.1' \
    -d '{
        "tos": "'"$(date --utc +"%Y-%m-%dT%H:%M:%S.%3NZ" | awk '{print substr($0, 1, length($0)-1)"-02:00"}')"'",
        "key": "'"$PUB"'"
    }')

ipv4=$(echo "$RESPONSE" | sed -n 's/.*"v4":"\([^"]*\)".*/\1/p')
ipv6=$(echo "$RESPONSE" | sed -n 's/.*"v6":"\([^"]*\)".*/\1/p')
client_hex=$(echo "$RESPONSE" | grep -o '"client_id":"[^"]*' | cut -d'"' -f4 | base64 -d | od -t x1 -An | tr -d ' \n')
public_key=$(echo "$RESPONSE" | sed -n 's/.*"public_key":"\([^"]*\)".*/\1/p')
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
            "private_key": "$PRI",
            "peers": [
                {
                    "address": "engage.cloudflareclient.com",
                    "port": 2408,
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

echo "$WARP_PART"

# sudo tee /etc/sing-box/config.json > /dev/null << EOF
# {
#     "log": {
#         "disabled": false,
#         "level": "debug",
#         "timestamp": true
#     },
#     "experimental": {
#         "cache_file": {
#             "enabled": true,
#             "path": "cache.db",
#             "cache_id": "v1"
#         }
#     },
#     "dns": {
#         "servers": [
#             {
#                 "tag": "ND-h3",
#                 "address": "h3://dns.nextdns.io/x",
#                 "address_resolver": "dns-direct",
#                 "detour": "direct-out"
#             },
#             {
#                 "tag": "dns-direct",
#                 "address": "udp://223.5.5.5",
#                 "detour": "direct-out"
#             }
#         ],
#         "strategy": "ipv4_only",
#         "final": "ND-h3",
#         "reverse_mapping": true,
#         "disable_cache": false,
#         "disable_expire": false
#     },
#     "route": {
#         "rules": [
#             {
#                 "inbound": "mixed-in",
#                 "action": "sniff",
#                 "sniffer": [
#                     "dns",
#                     "bittorrent",
#                     "http",
#                     "tls",
#                     "quic",
#                     "dtls"
#                 ]
#             },
#             {
#                 "protocol": "dns",
#                 "action": "hijack-dns"
#             },
#             {
#                 "ip_is_private": true,
#                 "action": "route",
#                 "outbound": "direct-out"
#             },
#             {
#                 "ip_cidr": [
#                     "0.0.0.0/8",
#                     "10.0.0.0/8",
#                     "127.0.0.0/8",
#                     "169.254.0.0/16",
#                     "172.16.0.0/12",
#                     "192.168.0.0/16",
#                     "224.0.0.0/4",
#                     "240.0.0.0/4",
#                     "52.80.0.0/16"
#                 ],
#                 "action": "route",
#                 "outbound": "direct-out"
#             }
#         ],
#         "auto_detect_interface": true,
#         "final": "WARP"
#     },
#     "inbounds": [
#         {
#             "type": "mixed",
#             "tag": "mixed-in",
#             "listen": "::",
#             "listen_port": 9091
#         }
#     ],
# $WARP_PART,
#     "outbounds": [
#         {
#             "tag": "direct-out",
#             "type": "direct",
#             "udp_fragment": true
#         }
#     ]
# }
# EOF

# sudo systemctl restart sing-box
# sudo systemctl stop sing-box
# sudo sing-box -c /etc/sing-box/config.json run
# curl -x "socks5h://127.0.0.1:9091" -fsSL "https://www.cloudflare.com/cdn-cgi/trace"