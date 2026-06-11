#!/bin/dash

OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
    ARCH=$(uname -m)
    BIN_DIR=/usr/local/bin
    sudo mkdir -p "$BIN_DIR"
elif command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt-get -qq update
    sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y unzip curl coreutils
    ARCH=$(dpkg --print-architecture)
    BIN_DIR=/usr/bin
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf -q -y install unzip curl coreutils
    ARCH=$(rpm --eval '%{_arch}')
    BIN_DIR=/usr/bin
else
    echo "[ERROR] Neither apt-get nor dnf found"
    exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
    SHA256SUM="sha256sum"
else
    SHA256SUM="shasum -a 256"
fi

case "$ARCH" in
    amd64|x86_64) RCLONE_ARCH=amd64 ;;
    arm64|aarch64) RCLONE_ARCH=arm64 ;;
    ppc64le|ppc64el)
        echo "[ERROR] rclone has no upstream prebuilt binary for ppc64le"
        echo "[INFO]  See https://github.com/rclone/rclone/releases for available targets"
        exit 1 ;;
    *) echo "[ERROR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

if [ "$OS" = "Darwin" ]; then
    RCLONE_OS=osx
else
    RCLONE_OS=linux
fi

RCLONE_BASE="https://github.com/rclone/rclone/releases"
RCLONE_VERSION=$(curl -fsSL -o /dev/null -w '%{url_effective}' "$RCLONE_BASE/latest" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')

if [ -z "$RCLONE_VERSION" ]; then
    echo "[ERROR] Failed to resolve latest rclone version"
    exit 1
fi

RCLONE_NAME="rclone-${RCLONE_VERSION}-${RCLONE_OS}-${RCLONE_ARCH}"
RCLONE="$RCLONE_BASE/download/${RCLONE_VERSION}/${RCLONE_NAME}.zip"
RCLONE_TMP=$(mktemp -d)

RCLONE_SUM=$(curl -fsSL "$RCLONE_BASE/download/${RCLONE_VERSION}/SHA256SUMS" | grep "${RCLONE_NAME}.zip" | grep -oE '^[a-f0-9]{64}')

if [ -z "$RCLONE_SUM" ]; then
    echo "[ERROR] Checksum for $RCLONE_NAME.zip not found in SHA256SUMS"
    rm -rf "$RCLONE_TMP"
    exit 1
fi

curl -fsSL -o "$RCLONE_TMP/rclone.zip" "$RCLONE"

RCLONE_ACTUAL=$($SHA256SUM "$RCLONE_TMP/rclone.zip" | cut -d' ' -f1)
if [ "$RCLONE_ACTUAL" != "$RCLONE_SUM" ]; then
    echo "[ERROR] Checksum mismatch: expected $RCLONE_SUM, got $RCLONE_ACTUAL"
    rm -rf "$RCLONE_TMP"
    exit 1
fi

unzip -q -o "$RCLONE_TMP/rclone.zip" -d "$RCLONE_TMP"

sudo install -m 0755 "$RCLONE_TMP/${RCLONE_NAME}/rclone" "$BIN_DIR/rclone"
rm -rf "$RCLONE_TMP"

"$BIN_DIR/rclone" version
