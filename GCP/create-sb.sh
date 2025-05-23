#!/bin/dash

_CF_ZONE="sub"
_CF_TOKEN_BASE64="base64encodedtoken"

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_ZONE="${2:-$_CF_ZONE}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

curl -fsSL bit.ly/create-sbox | sh
curl -fsSL bit.ly/create-cron | sh
curl -fsSL bit.ly/new-gcp-dns | sh -s -- "$CF_TOKEN_BASE64" "$CF_ZONE"

CF_DOMAIN=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)

IN_PART=$(cat <<EOF
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "::",
            "listen_port": 443,
            "users": [
                {
                    "flow": "xtls-rprx-vision",
                    "uuid": "$(echo "$CF_TOKEN_BASE64" | sha1sum | cut -c1-32 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\).*$/\1-\2-\3-\4-\5/')"
                },
                {
                    "flow": "xtls-rprx-vision",
                    "uuid": "$(echo "user-$CF_TOKEN_BASE64" | sha1sum | cut -c1-32 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\).*$/\1-\2-\3-\4-\5/')"
                },
                {
                    "flow": "xtls-rprx-vision",
                    "uuid": "$(echo "admin-$CF_TOKEN_BASE64" | sha1sum | cut -c1-32 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\).*$/\1-\2-\3-\4-\5/')"
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
$IN_PART
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
