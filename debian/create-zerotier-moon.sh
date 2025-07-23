#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <zerotier_port>"
    echo "Example:"
    echo "  $0 9993"
    echo "Create ZeroTier moon with auto-detected IP addresses"
    exit 1
fi

_ZT_PORT="9993"
ZT_PORT="${1:-$_ZT_PORT}"

echo "[INFO] Checking ZeroTier installation..."
if ! command -v zerotier-cli >/dev/null 2>&1; then
    echo "[INFO] ZeroTier not found. Installing..."
    if ! curl -fsSL https://bit.ly/create-zerotier | sh; then
        echo "[ERROR] Failed to install ZeroTier"
        exit 1
    fi
    echo "[SUCCESS] ZeroTier installed successfully"
else
    echo "[INFO] ZeroTier is already installed"
fi

echo "[INFO] Ensuring ZeroTier service is running..."
sudo systemctl enable zerotier-one >/dev/null 2>&1 || true
sudo systemctl start zerotier-one >/dev/null 2>&1 || true

sleep 2

echo "[INFO] Detecting default network interface..."
ZT_IFACE=$(ip route show default | awk '{print $5}')
if [ -z "$ZT_IFACE" ]; then
    echo "[ERROR] Unable to detect default network interface."
    exit 1
fi

echo "[INFO] Using interface: ZT_IFACE=$ZT_IFACE"
echo "[INFO] Detecting IP addresses..."

ZT_IPV4=$(ip addr show dev "$ZT_IFACE" | awk '/inet /{print $2; exit}' | cut -d'/' -f1)
ZT_IPV6=$(ip addr show dev "$ZT_IFACE" | awk '/inet6 /{print $2; exit}' | cut -d'/' -f1)

ZT_ENDPOINTS=""

if [ -n "$ZT_IPV4" ]; then
    echo "[INFO] IPv4 address: ZT_IPV4=$ZT_IPV4"
    ZT_ENDPOINTS="\"$ZT_IPV4/$ZT_PORT\""
fi

if [ -n "$ZT_IPV6" ]; then
    echo "[INFO] IPv6 address: ZT_IPV6=$ZT_IPV6"
    if [ -n "$ZT_ENDPOINTS" ]; then
        ZT_ENDPOINTS="$ZT_ENDPOINTS,\"$ZT_IPV6/$ZT_PORT\""
    else
        ZT_ENDPOINTS="\"$ZT_IPV6/$ZT_PORT\""
    fi
fi

echo "[INFO] Port: ZT_PORT=$ZT_PORT"
echo "[INFO] Stable endpoints: ZT_ENDPOINTS=[$ZT_ENDPOINTS]"

if [ -d "/var/lib/zerotier-one/moons.d" ] && [ -f "/var/lib/zerotier-one/identity.public" ]; then
    echo "[INFO] Moon already exists. Reading moon ID..."
    
    ZT_MOON_ID=$(cut -d ':' -f1 /var/lib/zerotier-one/identity.public)
    
    if [ -z "$ZT_MOON_ID" ]; then
        echo "[ERROR] Unable to read moon ID from identity.public"
        exit 1
    fi
    
    echo "[SUCCESS] Your ZeroTier moon ID is $ZT_MOON_ID"
    echo "[INFO] You can orbit this moon using: zerotier-cli orbit $ZT_MOON_ID $ZT_MOON_ID"
else
    echo "[INFO] Generating moon configuration..."
    sudo zerotier-idtool initmoon /var/lib/zerotier-one/identity.public | sudo tee -a /var/lib/zerotier-one/moon.json > /dev/null
    
    if [ ! -f /var/lib/zerotier-one/moon.json ]; then
        echo "[ERROR] Failed to create moon.json"
        exit 1
    fi
    
    echo "[INFO] Configuring stable endpoints..."
    sudo sed -i "s|\"stableEndpoints\": \[\]|\"stableEndpoints\": [$ZT_ENDPOINTS]|g" /var/lib/zerotier-one/moon.json
    echo "[INFO] Generating moon file..."
    sudo zerotier-idtool genmoon /var/lib/zerotier-one/moon.json >/dev/null
    
    if ! find . -maxdepth 1 -name '*.moon' | grep -q .; then
        echo "[ERROR] Failed to generate moon file"
        exit 1
    fi
    
    echo "[INFO] Installing moon file..."
    sudo mkdir -p /var/lib/zerotier-one/moons.d
    sudo find . -maxdepth 1 -type f -name "*.moon" -exec mv {} /var/lib/zerotier-one/moons.d/ \;
    
    echo "[INFO] Restarting ZeroTier..."
    sudo systemctl restart zerotier-one
    
    ZT_MOON_ID=$(grep '"id"' /var/lib/zerotier-one/moon.json | cut -d '"' -f4)
    
    if [ -z "$ZT_MOON_ID" ]; then
        echo "[ERROR] Unable to extract moon ID from moon.json"
        exit 1
    fi
    
    echo "[SUCCESS] ZeroTier moon created successfully."
    echo "[INFO] Your ZeroTier moon ID is $ZT_MOON_ID"
    echo "[INFO] You can orbit this moon using: sudo zerotier-cli orbit $ZT_MOON_ID $ZT_MOON_ID"
    echo "[INFO] To verify joined moon server: sudo zerotier-cli listmoons"
    echo "[INFO] To leave this moon later: sudo zerotier-cli deorbit $ZT_MOON_ID"
fi