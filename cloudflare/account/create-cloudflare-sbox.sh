#!/bin/dash

set +e

export DEBIAN_FRONTEND=noninteractive
SAGER_NET="https://sing-box.app/gpg.key"
CF_API_BASE="https://api.cloudflare.com/client/v4"

_CF_TOKEN_BASE64="base64encodedtoken"
_CF_SERVICE="example"
_PADDING_SCHEME="WyJzdG9wPTciLCIwPTE2LTE2IiwiMT04MC0yODAiLCIyPTIwMC0zMDAsYywzMDAtNjAwLGMsMzAwLTYwMCxjLDMwMC02MDAsYywzMDAtNjAwIiwiMz02LTYsMzUwLTcwMCIsIjQ9MzUwLTcwMCIsIjU9MzUwLTcwMCIsIjY9MzUwLTcwMCJd"

if [ -z "$1" ]; then
    echo "Usage: $0 <cloudflare_token> [service]"
    echo "Example:"
    echo "  $0 eW91ci10b2tlbg== example WyJzdG9wPTMiLCIwPTkwMC0xNDAwIiwiMT05MDAtMTQwMCIsIjI9OTAwLTE0MDAiXQo="
    exit 1
fi

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y gnupg2 curl jq

curl -fsSL "$SAGER_NET" | sudo -E gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/sagernet.gpg
echo "deb https://deb.sagernet.org * *" | sudo -E tee /etc/apt/sources.list.d/sagernet.list

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y sing-box

CF_TOKEN_BASE64="${1:-$_CF_TOKEN_BASE64}"
CF_SERVICE="${2:-$_CF_SERVICE}"
PADDING_SCHEME="${3:-$_PADDING_SCHEME}"
CF_TOKEN=$(echo "$CF_TOKEN_BASE64" | base64 -d)

CF_IP=$(curl -fsSL https://ipinfo.io/ip)
CF_ACCOUNT_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_TOKEN_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/verify" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_ZONE_ID=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/accounts/$CF_ACCOUNT_ID/tokens/$CF_TOKEN_ID" | grep -o 'com.cloudflare.api.account.zone.[^"]*' | sed 's/.*\.zone\.//')
CF_DOMAIN=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/zones/$CF_ZONE_ID" | grep -o '"name":"[^"]*' | cut -d'"' -f4 | head -n 1)
CF_RECORD=$(curl -fsSL -X GET -H "Authorization: Bearer $CF_TOKEN" "$CF_API_BASE/zones/${CF_ZONE_ID}/dns_records?name=${CF_SERVICE}.${CF_DOMAIN}" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -n 1)

if [ -z "$CF_IP" ]; then
    echo "Error: Unable to retrieve external IP address. Please check your internet connection."
    exit 1
fi

if [ -z "$CF_DOMAIN" ]; then
    echo "Error: Unable to retrieve domain. Please check your API token."
    exit 1
fi

if [ -z "$CF_ZONE_ID" ]; then
    echo "Error: Unable to retrieve Cloudflare zone ID for domain $CF_DOMAIN. Please check your API token with [Account API Tokens Read] setting and domain name."
    exit 1
fi

echo "[INFO] External IP: CF_IP=$CF_IP"
echo "[INFO] Domain: CF_DOMAIN=$CF_DOMAIN"
echo "[INFO] Zone ID: CF_ZONE_ID=$CF_ZONE_ID"
echo "[INFO] Service: CF_SERVICE=$CF_SERVICE"
echo "[INFO] Record ID: CF_RECORD=$CF_RECORD"

DNS_PAYLOAD='{
    "type": "A",
    "name": "'"${CF_SERVICE}.${CF_DOMAIN}"'",
    "content": "'"${CF_IP}"'",
    "proxied": false
}'

CONFIG_PAYLOAD=$(cat <<EOF
        {
            "type": "anytls",
            "tag": "anytls-in",
            "listen": "::",
            "listen_port": 443,
            "users": [
                {
                    "name": "trial",
                    "password": "$CF_TOKEN_BASE64"
                },
                {
                    "name": "user",
                    "password": "user-$CF_TOKEN_BASE64"
                },
                {
                    "name": "admin",
                    "password": "admin-$CF_TOKEN_BASE64"
                }
            ],
            "padding_scheme": $(echo "$PADDING_SCHEME" | base64 -d),
            "tls": {
                "enabled": true,
                "server_name": "$CF_SERVICE.$CF_DOMAIN",
                "min_version": "1.2",
                "max_version": "1.3",
                "acme": {
                    "domain": "$CF_SERVICE.$CF_DOMAIN",
                    "email": "admin@$CF_DOMAIN",
                    "dns01_challenge": {
                        "provider": "cloudflare",
                        "api_token": "$CF_TOKEN"
                    }
                },
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
EOF
)

if [ -z "$CF_RECORD" ]; then
    echo "[INFO] DNS record not found. Creating a new DNS record..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$CF_API_BASE/zones/${CF_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$DNS_PAYLOAD")
else
    echo "[INFO] DNS record found. Modifying the existing DNS record..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$CF_API_BASE/zones/${CF_ZONE_ID}/dns_records/${CF_RECORD}" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$DNS_PAYLOAD")
fi

if [ "$RESPONSE" -eq 200 ]; then
    echo "[SUCCESS] A record for ${CF_SERVICE}.${CF_DOMAIN} has been updated with IP ${CF_IP}."

sudo tee /etc/sing-box/config.json > /dev/null << EOF
{
    "inbounds": [
$CONFIG_PAYLOAD
    ]
}
EOF

sudo systemctl daemon-reload
sudo systemctl enable sing-box
sudo systemctl restart sing-box

sleep 30

sudo systemctl status sing-box --no-pager -l
else
    echo "[ERROR] Failed to create or modify A record for ${CF_SERVICE}.${CF_DOMAIN}. HTTP status code: $RESPONSE"
    exit 1
fi


# {
#     "chrome_like": "WyJzdG9wPTgiLCAiMD0zMC0zMCIsICIxPTEwMC00MDAiLCAiMj00MDAtNTAwLGMsNTAwLTEwMDAsYyw1MDAtMTAwMCxjLDUwMC0xMDAwLGMsNTAwLTEwMDAiLCAiMz05LTksNTAwLTEwMDAiLCAiND01MDAtMTAwMCIsICI1PTUwMC0xMDAwIiwgIjY9NTAwLTEwMDAiLCAiNz01MDAtMTAwMCJd",
#     "firefox_like": "WyJzdG9wPTgiLCAiMD0yMS0yMSIsICIxPTgwLTMyMCIsICIyPTM1MC00NTAsYyw0NTAtODUwLGMsNDUwLTg1MCxjLDQ1MC04NTAsYyw0NTAtODUwIiwgIjM9MTEtMTEsNDAwLTgwMCIsICI0PTQwMC04MDAiLCAiNT00MDAtODAwIiwgIjY9NDAwLTgwMCIsICI3PTQwMC04MDAiXQ==",
#     "safari_like": "WyJzdG9wPTgiLCAiMD0xNi0xNiIsICIxPTEyOC01MTIiLCAiMj0yNTYtMzg0LGMsMzg0LTc2OCxjLDM4NC03NjgsYywzODQtNzY4LGMsMzg0LTc2OCIsICIzPTgtOCw1MTItMTAyNCIsICI0PTUxMi0xMDI0IiwgIjU9NTEyLTEwMjQiLCAiNj01MTItMTAyNCIsICI3PTUxMi0xMDI0Il0=",
#     "lightweight": "WyJzdG9wPTgiLCAiMD0xMi0xMiIsICIxPTY0LTI1NiIsICIyPTIwMC0zMDAsYywzMDAtNjAwLGMsMzAwLTYwMCxjLDMwMC02MDAsYywzMDAtNjAwIiwgIjM9Ni02LDMwMC02MDAiLCAiND0zMDAtNjAwIiwgIjU9MzAwLTYwMCIsICI2PTMwMC02MDAiLCAiNz0zMDAtNjAwIl0=",
#     "aggressive": "WyJzdG9wPTgiLCAiMD00MC00MCIsICIxPTIwMC04MDAiLCAiMj02MDAtODAwLGMsODAwLTE1MDAsYyw4MDAtMTUwMCxjLDgwMC0xNTAwLGMsODAwLTE1MDAiLCAiMz0xNS0xNSw4MDAtMTUwMCIsICI0PTgwMC0xNTAwIiwgIjU9ODAwLTE1MDAiLCAiNj04MDAtMTUwMCIsICI3PTgwMC0xNTAwIl0=",
#     "stealth": "WyJzdG9wPTgiLCAiMD0zMS0zMSIsICIxPTEyNy01MDkiLCAiMj00MDEtNTAzLGMsNTAzLTk5NyxjLDQ5OS0xMDAzLGMsNTAxLTk5OSxjLDQ5Ny0xMDAxIiwgIjM9MTAtMTAsNTAzLTk5NyIsICI0PTQ5OS0xMDAxIiwgIjU9NTAxLTk5OSIsICI2PTUwMy05OTciLCAiNz00OTctMTAwMyJd",
#     "minimal": "WyJzdG9wPTgiLCAiMD04LTgiLCAiMT0zMi0xMjgiLCAiMj0xMjgtMjU2LGMsMjU2LTUxMixjLDI1Ni01MTIsYywyNTYtNTEyLGMsMjU2LTUxMiIsICIzPTQtNCwyNTYtNTEyIiwgIjQ9MjU2LTUxMiIsICI1PTI1Ni01MTIiLCAiNj0yNTYtNTEyIiwgIjc9MjU2LTUxMiJd",
#     "gaming": "WyJzdG9wPTgiLCAiMD0yMC0yMCIsICIxPTY0LTMyMCIsICIyPTI1Ni0zODQsYywzODQtNjQwLGMsMzg0LTY0MCxjLDM4NC02NDAsYywzODQtNjQwIiwgIjM9OC04LDM4NC02NDAiLCAiND0zODQtNjQwIiwgIjU9Mzg0LTY0MCIsICI2PTM4NC02NDAiLCAiNz0zODQtNjQwIl0=",
#     "balanced": "WyJzdG9wPTgiLCAiMD0yNS0yNSIsICIxPTE1MC02MDAiLCAiMj00NTAtNjUwLGMsNjUwLTExNTAsYyw2NTAtMTE1MCxjLDY1MC0xMTUwLGMsNjUwLTExNTAiLCAiMz0xMC0xMCw2NTAtMTE1MCIsICI0PTY1MC0xMTUwIiwgIjU9NjUwLTExNTAiLCAiNj02NTAtMTE1MCIsICI3PTY1MC0xMTUwIl0=",
#     "power2_optimized": "WyJzdG9wPTgiLCAiMD0zMi0zMiIsICIxPTEyOC01MTIiLCAiMj01MTItNjQwLGMsNjQwLTEwMjQsYyw2NDAtMTAyNCxjLDY0MC0xMDI0LGMsNjQwLTEwMjQiLCAiMz0xNi0xNiw2NDAtMTAyNCIsICI0PTY0MC0xMDI0IiwgIjU9NjQwLTEwMjQiLCAiNj02NDAtMTAyNCIsICI3PTY0MC0xMDI0Il0=",
#     "asymmetric": "WyJzdG9wPTgiLCAiMD0yMy0yMyIsICIxPTE1MC00NTAiLCAiMj0zMDAtNTAwLGMsNDAwLTkwMCxjLDUwMC04MDAsYyw2MDAtNzAwLGMsNDAwLTEwMDAiLCAiMz0xMy0xMyw1NTAtOTUwIiwgIjQ9NjAwLTkwMCIsICI1PTUwMC0xMTAwIiwgIjY9NzAwLTgwMCIsICI3PTQ1MC0xMDUwIl0=",
#     "enterprise": "WyJzdG9wPTgiLCAiMD0yNC0yNCIsICIxPTI1Ni03NjgiLCAiMj01MTItNzY4LGMsNzY4LTEyODAsYyw3NjgtMTI4MCxjLDc2OC0xMjgwLGMsNzY4LTEyODAiLCAiMz0xMi0xMiw3NjgtMTI4MCIsICI0PTc2OC0xMjgwIiwgIjU9NzY4LTEyODAiLCAiNj03NjgtMTI4MCIsICI3PTc2OC0xMjgwIl0=",
#     "cdn_optimized": "WyJzdG9wPTgiLCAiMD0yOC0yOCIsICIxPTIwMC02MDAiLCAiMj00MDAtNjAwLGMsNjAwLTEyMDAsYyw2MDAtMTIwMCxjLDYwMC0xMjAwLGMsNjAwLTEyMDAiLCAiMz0xNC0xNCw2MDAtMTIwMCIsICI0PTYwMC0xMjAwIiwgIjU9NjAwLTEyMDAiLCAiNj02MDAtMTIwMCIsICI3PTYwMC0xMjAwIl0=",
#     "mobile_optimized": "WyJzdG9wPTgiLCAiMD0xOC0xOCIsICIxPTk2LTM4NCIsICIyPTI1Ni00NDgsYyw0NDgtODk2LGMsNDQ4LTg5NixjLDQ0OC04OTYsYyw0NDgtODk2IiwgIjM9Ny03LDQ0OC04OTYiLCAiND00NDgtODk2IiwgIjU9NDQ4LTg5NiIsICI2PTQ0OC04OTYiLCAiNz00NDgtODk2Il0=",
#     "tor_like": "WyJzdG9wPTgiLCAiMD0yNy0yNyIsICIxPTI1Ni01MTIiLCAiMj01MTQtNTE0LGMsNTE0LTUxNCxjLDUxNC01MTQsYyw1MTQtNTE0LGMsNTE0LTUxNCIsICIzPTExLTExLDUxNC01MTQiLCAiND01MTQtNTE0IiwgIjU9NTE0LTUxNCIsICI2PTUxNC01MTQiLCAiNz01MTQtNTE0Il0=",
#     "dynamic_range": "WyJzdG9wPTgiLCAiMD0xNS00NSIsICIxPTEwMC04MDAiLCAiMj0yMDAtMTYwMCxjLDIwMC0xNjAwLGMsMjAwLTE2MDAsYywyMDAtMTYwMCxjLDIwMC0xNjAwIiwgIjM9NS0yMCwyMDAtMTYwMCIsICI0PTIwMC0xNjAwIiwgIjU9MjAwLTE2MDAiLCAiNj0yMDAtMTYwMCIsICI3PTIwMC0xNjAwIl0=",
#     "datacenter": "WyJzdG9wPTgiLCAiMD0zNi0zNiIsICIxPTUxMi0yMDQ4IiwgIjI9MTAyNC0xNTM2LGMsMTUzNi0zMDcyLGMsMTUzNi0zMDcyLGMsMTUzNi0zMDcyLGMsMTUzNi0zMDcyIiwgIjM9MTgtMTgsMTUzNi0zMDcyIiwgIjQ9MTUzNi0zMDcyIiwgIjU9MTUzNi0zMDcyIiwgIjY9MTUzNi0zMDcyIiwgIjc9MTUzNi0zMDcyIl0=",
#     "iot": "WyJzdG9wPTgiLCAiMD00LTQiLCAiMT0xNi02NCIsICIyPTY0LTEyOCxjLDEyOC0yNTYsYywxMjgtMjU2LGMsMTI4LTI1NixjLDEyOC0yNTYiLCAiMz0yLTIsMTI4LTI1NiIsICI0PTEyOC0yNTYiLCAiNT0xMjgtMjU2IiwgIjY9MTI4LTI1NiIsICI3PTEyOC0yNTYiXQ==",
#     "regional_asia": "WyJzdG9wPTgiLCAiMD0zMy0zMyIsICIxPTE4OC02ODgiLCAiMj0zODgtNTg4LGMsNTg4LTEwODgsYyw1ODgtMTA4OCxjLDU4OC0xMDg4LGMsNTg4LTEwODgiLCAiMz04LTgsNTg4LTEwODgiLCAiND01ODgtMTA4OCIsICI1PTU4OC0xMDg4IiwgIjY9NTg4LTEwODgiLCAiNz01ODgtMTA4OCJd",
#     "cloud_native": "WyJzdG9wPTgiLCAiMD0yNi0yNiIsICIxPTI1Ni0xMDI0IiwgIjI9NTEyLTEwMjQsYywxMDI0LTIwNDgsYywxMDI0LTIwNDgsYywxMDI0LTIwNDgsYywxMDI0LTIwNDgiLCAiMz0xMy0xMywxMDI0LTIwNDgiLCAiND0xMDI0LTIwNDgiLCAiNT0xMDI0LTIwNDgiLCAiNj0xMDI0LTIwNDgiLCAiNz0xMDI0LTIwNDgiXQ==",
#     "ultra_minimal_stop3": "WyJzdG9wPTMiLCAiMD04LTgiLCAiMT0zMi0xMjgiLCAiMj0xMjgtMjU2LGMsMjU2LTUxMiJd",
#     "quick_burst_stop3": "WyJzdG9wPTMiLCAiMD0xMi0xMiIsICIxPTY0LTI1NiIsICIyPTI1Ni03NjgsYyw3NjgtMTAyNCxjLDc2OC0xMDI0Il0=",
#     "minimal_fast_stop4": "WyJzdG9wPTQiLCAiMD0xNi0xNiIsICIxPTY0LTI1NiIsICIyPTI1Ni01MTIsYyw1MTItNzY4LGMsNTEyLTc2OCIsICIzPTUxMi03NjgiXQ==",
#     "compact_browser_stop4": "WyJzdG9wPTQiLCAiMD0yMC0yMCIsICIxPTEwMC00MDAiLCAiMj00MDAtNjAwLGMsNjAwLTEwMDAsYyw2MDAtMTAwMCIsICIzPTgtOCw2MDAtMTAwMCJd",
#     "iot_ultra_stop4": "WyJzdG9wPTQiLCAiMD00LTQiLCAiMT0xNi02NCIsICIyPTY0LTEyOCxjLDEyOC0yNTYiLCAiMz0xMjgtMjU2Il0=",
#     "balanced_five_stop5": "WyJzdG9wPTUiLCAiMD0yMC0yMCIsICIxPTEwMC00MDAiLCAiMj00MDAtNjAwLGMsNjAwLTkwMCxjLDYwMC05MDAiLCAiMz04LTgsNjAwLTkwMCIsICI0PTYwMC05MDAiXQ==",
#     "prime_five_stop5": "WyJzdG9wPTUiLCAiMD0xNy0xNyIsICIxPTk3LTM5NyIsICIyPTM5Ny01OTksYyw1OTktOTk3LGMsNzk3LTk5NyIsICIzPTExLTExLDU5OS05OTciLCAiND01OTktOTk3Il0=",
#     "balanced_six_stop6": "WyJzdG9wPTYiLCAiMD0yNC0yNCIsICIxPTEyOC01MTIiLCAiMj00MDAtNjAwLGMsNjAwLTEwMDAsYyw2MDAtMTAwMCxjLDYwMC0xMDAwIiwgIjM9MTAtMTAsNjAwLTEwMDAiLCAiND02MDAtMTAwMCIsICI1PTYwMC0xMDAwIl0=",
#     "progressive_six_stop6": "WyJzdG9wPTYiLCAiMD0xMi0xMiIsICIxPTUwLTIwMCIsICIyPTIwMC00MDAsYyw0MDAtNjAwLGMsNjAwLTgwMCIsICIzPTctNyw4MDAtMTAwMCIsICI0PTEwMDAtMTIwMCIsICI1PTEyMDAtMTQwMCJd",
#     "mobile_six_stop6": "WyJzdG9wPTYiLCAiMD0xNS0xNSIsICIxPTgwLTMyMCIsICIyPTMyMC00ODAsYyw0ODAtNzIwLGMsNDgwLTcyMCIsICIzPTYtNiw0ODAtNzIwIiwgIjQ9NDgwLTcyMCIsICI1PTQ4MC03MjAiXQ==",
#     "lucky_seven_stop7": "WyJzdG9wPTciLCAiMD0yNy0yNyIsICIxPTEyNy01MTEiLCAiMj01MTEtNzY3LGMsNzY3LTEwMjMsYyw3NjctMTAyMyxjLDc2Ny0xMDIzIiwgIjM9MTEtMTEsNzY3LTEwMjMiLCAiND03NjctMTAyMyIsICI1PTc2Ny0xMDIzIiwgIjY9NzY3LTEwMjMiXQ==",
#     "weekday_stop7": "WyJzdG9wPTciLCAiMD0yNC0yNCIsICIxPTE2OC01MDQiLCAiMj01MDQtODQwLGMsODQwLTExNzYsYyw4NDAtMTE3NiIsICIzPTctNyw4NDAtMTE3NiIsICI0PTg0MC0xMTc2IiwgIjU9ODQwLTExNzYiLCAiNj04NDAtMTE3NiJd",
#     "enhanced_security_stop10": "WyJzdG9wPTEwIiwgIjA9MzItMzIiLCAiMT0xMjgtNTEyIiwgIjI9NTEyLTc2OCxjLDc2OC0xMDI0LGMsNzY4LTEwMjQsYyw3NjgtMTAyNCxjLDc2OC0xMDI0IiwgIjM9MTItMTIsNzY4LTEwMjQiLCAiND03NjgtMTAyNCIsICI1PTc2OC0xMDI0IiwgIjY9NzY4LTEwMjQiLCAiNz03NjgtMTAyNCIsICI4PTc2OC0xMDI0IiwgIjk9NzY4LTEwMjQiXQ==",
#     "variable_ten_stop10": "WyJzdG9wPTEwIiwgIjA9MjUtMjUiLCAiMT0xMDAtMzAwIiwgIjI9MzAwLTUwMCxjLDUwMC03MDAsYyw3MDAtOTAwIiwgIjM9OS05LDQwMC04MDAiLCAiND01MDAtOTAwIiwgIjU9NjAwLTEwMDAiLCAiNj03MDAtMTEwMCIsICI3PTgwMC0xMjAwIiwgIjg9OTAwLTEzMDAiLCAiOT0xMDAwLTE0MDAiXQ==",
#     "datacenter_ten_stop10": "WyJzdG9wPTEwIiwgIjA9NDAtNDAiLCAiMT0yNTYtMTAyNCIsICIyPTEwMjQtMTUzNixjLDE1MzYtMjA0OCxjLDE1MzYtMjA0OCxjLDE1MzYtMjA0OCIsICIzPTE2LTE2LDE1MzYtMjA0OCIsICI0PTE1MzYtMjA0OCIsICI1PTE1MzYtMjA0OCIsICI2PTE1MzYtMjA0OCIsICI3PTE1MzYtMjA0OCIsICI4PTE1MzYtMjA0OCIsICI5PTE1MzYtMjA0OCJd",
#     "extreme_obfuscation_stop12": "WyJzdG9wPTEyIiwgIjA9MzUtMzUiLCAiMT0yMDAtODAwIiwgIjI9ODAwLTEyMDAsYywxMjAwLTE2MDAsYywxMjAwLTE2MDAsYywxMjAwLTE2MDAsYywxMjAwLTE2MDAiLCAiMz0xNS0xNSwxMjAwLTE2MDAiLCAiND0xMjAwLTE2MDAiLCAiNT0xMjAwLTE2MDAiLCAiNj0xMjAwLTE2MDAiLCAiNz0xMjAwLTE2MDAiLCAiOD0xMjAwLTE2MDAiLCAiOT0xMjAwLTE2MDAiLCAiMTA9MTIwMC0xNjAwIiwgIjExPTEyMDAtMTYwMCJd",
#     "fibonacci_twelve_stop12": "WyJzdG9wPTEyIiwgIjA9MTMtMTMiLCAiMT0yMS0zNCIsICIyPTM0LTU1LGMsNTUtODksYyw4OS0xNDQiLCAiMz04LTgsMTQ0LTIzMyIsICI0PTIzMy0zNzciLCAiNT0zNzctNjEwIiwgIjY9NjEwLTk4NyIsICI3PTk4Ny0xNTk3IiwgIjg9NjEwLTk4NyIsICI5PTM3Ny02MTAiLCAiMTA9MjMzLTM3NyIsICIxMT0xNDQtMjMzIl0=",
#     "maximum_positions_stop16": "WyJzdG9wPTE2IiwgIjA9NDgtNDgiLCAiMT0yNTYtMTAyNCIsICIyPTEwMjQtMTUzNixjLDE1MzYtMjA0OCxjLDE1MzYtMjA0OCxjLDE1MzYtMjA0OCxjLDE1MzYtMjA0OCIsICIzPTIwLTIwLDE1MzYtMjA0OCIsICI0PTE1MzYtMjA0OCIsICI1PTE1MzYtMjA0OCIsICI2PTE1MzYtMjA0OCIsICI3PTE1MzYtMjA0OCIsICI4PTE1MzYtMjA0OCIsICI5PTE1MzYtMjA0OCIsICIxMD0xNTM2LTIwNDgiLCAiMTE9MTUzNi0yMDQ4IiwgIjEyPTE1MzYtMjA0OCIsICIxMz0xNTM2LTIwNDgiLCAiMTQ9MTUzNi0yMDQ4IiwgIjE1PTE1MzYtMjA0OCJd",
#     "binary_tree_stop16": "WyJzdG9wPTE2IiwgIjA9MTYtMTYiLCAiMT0zMi02NCIsICIyPTY0LTEyOCxjLDEyOC0yNTYiLCAiMz00LTQsMjU2LTUxMiIsICI0PTUxMi0xMDI0IiwgIjU9NTEyLTEwMjQiLCAiNj01MTItMTAyNCIsICI3PTUxMi0xMDI0IiwgIjg9MjU2LTUxMiIsICI5PTI1Ni01MTIiLCAiMTA9MjU2LTUxMiIsICIxMT0yNTYtNTEyIiwgIjEyPTEyOC0yNTYiLCAiMTM9MTI4LTI1NiIsICIxND02NC0xMjgiLCAiMTU9MzItNjQiXQ==",
#     "realtime_stop3": "WyJzdG9wPTMiLCAiMD02LTYiLCAiMT0yNC05NiIsICIyPTk2LTE5MixjLDE5Mi0zODQiXQ==",
#     "mobile_optimized_stop4": "WyJzdG9wPTQiLCAiMD0xNC0xNCIsICIxPTU2LTIyNCIsICIyPTIyNC00NDgsYyw0NDgtNjcyIiwgIjM9NDQ4LTY3MiJd",
#     "api_gateway_stop5": "WyJzdG9wPTUiLCAiMD0yNS0yNSIsICIxPTEyNS01MDAiLCAiMj01MDAtNzUwLGMsNzUwLTEwMDAiLCAiMz0xMC0xMCw3NTAtMTAwMCIsICI0PTc1MC0xMDAwIl0=",
#     "edge_computing_stop6": "WyJzdG9wPTYiLCAiMD0xOC0xOCIsICIxPTk2LTM4NCIsICIyPTM4NC01NzYsYyw1NzYtODY0LGMsNTc2LTg2NCIsICIzPTktOSw1NzYtODY0IiwgIjQ9NTc2LTg2NCIsICI1PTU3Ni04NjQiXQ==",
#     "gaming_stop7": "WyJzdG9wPTciLCAiMD0yMS0yMSIsICIxPTEwNS00MjAiLCAiMj00MjAtNjMwLGMsNjMwLTk0NSxjLDYzMC05NDUiLCAiMz03LTcsNjMwLTk0NSIsICI0PTYzMC05NDUiLCAiNT02MzAtOTQ1IiwgIjY9NjMwLTk0NSJd",
#     "anonymity_stop10": "WyJzdG9wPTEwIiwgIjA9MzUtMzUiLCAiMT0xNzUtNzAwIiwgIjI9NzAwLTEwNTAsYywxMDUwLTE0MDAsYywxMDUwLTE0MDAiLCAiMz0xNC0xNCwxMDUwLTE0MDAiLCAiND0xMDUwLTE0MDAiLCAiNT0xMDUwLTE0MDAiLCAiNj0xMDUwLTE0MDAiLCAiNz0xMDUwLTE0MDAiLCAiOD0xMDUwLTE0MDAiLCAiOT0xMDUwLTE0MDAiXQ==",
#     "government_stop12": "WyJzdG9wPTEyIiwgIjA9NDAtNDAiLCAiMT0yNDAtOTYwIiwgIjI9OTYwLTE0NDAsYywxNDQwLTE5MjAsYywxNDQwLTE5MjAiLCAiMz0xNi0xNiwxNDQwLTE5MjAiLCAiND0xNDQwLTE5MjAiLCAiNT0xNDQwLTE5MjAiLCAiNj0xNDQwLTE5MjAiLCAiNz0xNDQwLTE5MjAiLCAiOD0xNDQwLTE5MjAiLCAiOT0xNDQwLTE5MjAiLCAiMTA9MTQ0MC0xOTIwIiwgIjExPTE0NDAtMTkyMCJd",
#     "military_grade_stop16": "WyJzdG9wPTE2IiwgIjA9NjQtNjQiLCAiMT0zODQtMTUzNiIsICIyPTE1MzYtMjMwNCxjLDIzMDQtMzA3MixjLDIzMDQtMzA3MiIsICIzPTI0LTI0LDIzMDQtMzA3MiIsICI0PTIzMDQtMzA3MiIsICI1PTIzMDQtMzA3MiIsICI2PTIzMDQtMzA3MiIsICI3PTIzMDQtMzA3MiIsICI4PTIzMDQtMzA3MiIsICI5PTIzMDQtMzA3MiIsICIxMD0yMzA0LTMwNzIiLCAiMTE9MjMwNC0zMDcyIiwgIjEyPTIzMDQtMzA3MiIsICIxMz0yMzA0LTMwNzIiLCAiMTQ9MjMwNC0zMDcyIiwgIjE1PTIzMDQtMzA3MiJd"
# }

# curl -fsSL https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/cloudflare/account/create-cloudflare-token.sh | sh -s -- root_token
# curl -fsSL https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/cloudflare/account/create-cloudflare-sbox.sh | sh -s -- token service

echo ""
echo "[INFO] Generating configuration: /tmp/$CF_SERVICE.txt"

curl -fsSL https://bit.ly/create-cloudflare-config | sh -s -- "$CF_TOKEN_BASE64" "$CF_SERVICE" "$CF_DOMAIN" "$CF_IP"