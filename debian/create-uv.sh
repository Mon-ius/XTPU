#!/bin/dash

OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
    ARCH=$(uname -m)
    BIN_DIR=/usr/local/bin
    sudo mkdir -p "$BIN_DIR"
elif command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt-get -qq update
    sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y tar curl
    ARCH=$(dpkg --print-architecture)
    BIN_DIR=/usr/bin
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf -q -y install tar curl
    ARCH=$(rpm --eval '%{_arch}')
    BIN_DIR=/usr/bin
else
    echo "[ERROR] Neither apt-get nor dnf found"
    exit 1
fi

case "$ARCH" in
    amd64|x86_64) UV_ARCH=x86_64 ;;
    arm64|aarch64) UV_ARCH=aarch64 ;;
    ppc64le|ppc64el) UV_ARCH=powerpc64le ;;
    *) echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

if [ "$OS" = "Darwin" ]; then
    UV_TRIPLE="${UV_ARCH}-apple-darwin"
elif [ "$UV_ARCH" = "powerpc64le" ]; then
    UV_TRIPLE="${UV_ARCH}-unknown-linux-gnu"
else
    UV_TRIPLE="${UV_ARCH}-unknown-linux-musl"
fi

UV="https://github.com/astral-sh/uv/releases/latest/download/uv-${UV_TRIPLE}.tar.gz"
UV_TMP=$(mktemp -d)

curl -fsSL -o "$UV_TMP/uv.tar.gz" "$UV"
tar -xzf "$UV_TMP/uv.tar.gz" -C "$UV_TMP"

sudo install -m 0755 "$UV_TMP/uv-${UV_TRIPLE}/uv" "$BIN_DIR/uv"
sudo install -m 0755 "$UV_TMP/uv-${UV_TRIPLE}/uvx" "$BIN_DIR/uvx"
rm -rf "$UV_TMP"

"$BIN_DIR/uv" --version
