#!/bin/dash

if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt-get -qq update
    sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y tar curl bubblewrap
    ARCH=$(dpkg --print-architecture)
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf -q -y install tar curl bubblewrap
    ARCH=$(rpm --eval '%{_arch}')
else
    echo "[ERROR] Neither apt-get nor dnf found"
    exit 1
fi

case "$ARCH" in
    amd64|x86_64) CODEX_ARCH=x86_64 ;;
    arm64|aarch64) CODEX_ARCH=aarch64 ;;
    ppc64le|ppc64el)
        echo "[ERROR] codex has no upstream prebuilt binary for ppc64le"
        echo "[INFO]  See https://github.com/openai/codex/releases for available targets"
        exit 1 ;;
    *) echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

CODEX="https://github.com/openai/codex/releases/latest/download/codex-${CODEX_ARCH}-unknown-linux-musl.tar.gz"
CODEX_TMP=$(mktemp -d)

curl -fsSL -o "$CODEX_TMP/codex.tar.gz" "$CODEX"
tar -xzf "$CODEX_TMP/codex.tar.gz" -C "$CODEX_TMP"

sudo install -m 0755 "$CODEX_TMP/codex-${CODEX_ARCH}-unknown-linux-musl" /usr/bin/codex
rm -rf "$CODEX_TMP"

codex --version
