#!/bin/dash

_CF_ZONE="sub"
_CF_TOKEN="base64encodedtoken"

CF_TOKEN="${1:-$_CF_TOKEN}"
CF_ZONE="${2:-$_CF_ZONE}"

curl -fsSL bit.ly/new-gcp-dns | sh -s -- "$CF_TOKEN" "$CF_ZONE"
curl -fsSL bit.ly/create-sbox | sh

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
    "inbounds": [
$HY2_PART
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
