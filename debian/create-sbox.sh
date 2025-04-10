#!/bin/dash

export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y gnupg2 curl jq

if [ -f "/usr/bin/sing-box-beta" ]; then
    echo "sing-box-beta found at /usr/bin/sing-box-beta"
    sudo -E apt-get -qq remove --purge -y sing-box
fi

SAGER_NET="https://sing-box.app/gpg.key"
curl -fsSL "$SAGER_NET" | sudo -E gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/sagernet.gpg
echo "deb https://deb.sagernet.org * *" | sudo -E tee /etc/apt/sources.list.d/sagernet.list

sudo -E apt-get -qq update
if ! dpkg -l "sing-box" 2>/dev/null | grep -q '^ii'; then
    sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y sing-box
fi

is_reboot=$(apt list --upgradable 2>/dev/null | grep -q "^sing-box/" && echo true || echo false)
if [ "$is_reboot" = true ]; then
    sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y sing-box
    sudo /usr/sbin/reboot
fi