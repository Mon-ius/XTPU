#!/bin/dash

export DEBIAN_FRONTEND=noninteractive

sudo -E apt-get -qq update
sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y curl coreutils

ARCH=$(dpkg --print-architecture)
case "$ARCH" in
    amd64) CLAUDE_ARCH=x64 ;;
    arm64) CLAUDE_ARCH=arm64 ;;
    *) echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

CLAUDE_BASE="https://downloads.claude.ai/claude-code-releases"
CLAUDE_PLATFORM="linux-${CLAUDE_ARCH}"
CLAUDE_TMP=$(mktemp -d)

CLAUDE_VERSION=$(curl -fsSL "$CLAUDE_BASE/latest")
CLAUDE_MANIFEST=$(curl -fsSL "$CLAUDE_BASE/$CLAUDE_VERSION/manifest.json" | tr -d '\n\r\t ')
CLAUDE_SUM=$(echo "$CLAUDE_MANIFEST" | grep -oE "\"$CLAUDE_PLATFORM\":\\{[^}]*\"checksum\":\"[a-f0-9]{64}\"" | grep -oE '[a-f0-9]{64}')

if [ -z "$CLAUDE_SUM" ]; then
    echo "[ERROR] Platform $CLAUDE_PLATFORM not found in manifest"
    rm -rf "$CLAUDE_TMP"
    exit 1
fi

curl -fsSL -o "$CLAUDE_TMP/claude" "$CLAUDE_BASE/$CLAUDE_VERSION/$CLAUDE_PLATFORM/claude"

CLAUDE_ACTUAL=$(sha256sum "$CLAUDE_TMP/claude" | cut -d' ' -f1)
if [ "$CLAUDE_ACTUAL" != "$CLAUDE_SUM" ]; then
    echo "[ERROR] Checksum mismatch: expected $CLAUDE_SUM, got $CLAUDE_ACTUAL"
    rm -rf "$CLAUDE_TMP"
    exit 1
fi

sudo install -m 0755 "$CLAUDE_TMP/claude" /usr/bin/claude
rm -rf "$CLAUDE_TMP"

claude --version
