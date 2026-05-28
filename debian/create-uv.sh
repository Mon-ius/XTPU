#!/bin/dash

if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt-get -qq update
    sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y tar curl
    ARCH=$(dpkg --print-architecture)
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf -q -y install tar curl
    ARCH=$(rpm --eval '%{_arch}')
else
    echo "[ERROR] Neither apt-get nor dnf found"
    exit 1
fi

case "$ARCH" in
    amd64|x86_64) UV_TRIPLE=x86_64-unknown-linux-musl ;;
    arm64|aarch64) UV_TRIPLE=aarch64-unknown-linux-musl ;;
    ppc64le|ppc64el) UV_TRIPLE=powerpc64le-unknown-linux-gnu ;;
    *) echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

UV="https://github.com/astral-sh/uv/releases/latest/download/uv-${UV_TRIPLE}.tar.gz"
UV_TMP=$(mktemp -d)

curl -fsSL -o "$UV_TMP/uv.tar.gz" "$UV"
tar -xzf "$UV_TMP/uv.tar.gz" -C "$UV_TMP"

sudo install -m 0755 "$UV_TMP/uv-${UV_TRIPLE}/uv" /usr/bin/uv
sudo install -m 0755 "$UV_TMP/uv-${UV_TRIPLE}/uvx" /usr/bin/uvx
rm -rf "$UV_TMP"

uv --version
