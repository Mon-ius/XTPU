#!/bin/dash

export DEBIAN_FRONTEND=noninteractive

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y tar curl

ARCH=$(dpkg --print-architecture)
GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -n 1 | sed 's/go//')
GOLANG="https://golang.org/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz"

sudo rm -rf /usr/local/go
curl -sSL "$GOLANG" | sudo tar -xz -C /usr/local
cat <<'EOF' | tee -a "$HOME/.profile"
export PATH=$PATH:/usr/local/go/bin
EOF
ln -s "$HOME/.profile" "$HOME/.zprofile"

export PATH=$PATH:/usr/local/go/bin