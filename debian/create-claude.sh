#!/bin/dash

export DEBIAN_FRONTEND=noninteractive

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y tar curl

ARCH=$(dpkg --print-architecture)
case "$ARCH" in
    amd64) CLAUDE_ARCH=x64 ;;
    arm64) CLAUDE_ARCH=arm64 ;;
    *) echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

CLAUDE="https://github.com/anthropics/claude-code/releases/latest/download/claude-linux-${CLAUDE_ARCH}-musl.tar.gz"
CLAUDE_TMP=$(mktemp -d)

curl -fsSL -o "$CLAUDE_TMP/claude.tar.gz" "$CLAUDE"
tar -xzf "$CLAUDE_TMP/claude.tar.gz" -C "$CLAUDE_TMP"

sudo install -m 0755 "$CLAUDE_TMP/claude" /usr/bin/claude
rm -rf "$CLAUDE_TMP"

claude --version
