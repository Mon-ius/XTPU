#!/bin/dash

export DEBIAN_FRONTEND=noninteractive

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y tar curl

ARCH=$(dpkg --print-architecture)
case "$ARCH" in
    amd64) CODEX_ARCH=x86_64 ;;
    arm64) CODEX_ARCH=aarch64 ;;
    *) echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

CODEX="https://github.com/openai/codex/releases/latest/download/codex-${CODEX_ARCH}-unknown-linux-musl.tar.gz"
CODEX_TMP=$(mktemp -d)

curl -fL -o "$CODEX_TMP/codex.tar.gz" "$CODEX"
tar -xzf "$CODEX_TMP/codex.tar.gz" -C "$CODEX_TMP"

sudo install -m 0755 "$CODEX_TMP/codex-${CODEX_ARCH}-unknown-linux-musl" /usr/bin/codex
rm -rf "$CODEX_TMP"

codex --version
