#!/bin/dash

OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
    LIB_DIR=/usr/local/lib
    BIN_DIR=/usr/local/bin
    sudo mkdir -p "$LIB_DIR" "$BIN_DIR"
elif command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    sudo -E apt-get -qq update
    sudo -E apt-get -qq install -o Dpkg::Options::="--force-confold" -y unzip curl
    LIB_DIR=/usr/lib
    BIN_DIR=/usr/bin
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf -q -y install unzip curl
    LIB_DIR=/usr/lib
    BIN_DIR=/usr/bin
else
    echo "[ERROR] Neither apt-get nor dnf found"
    exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    echo "[ERROR] node is required; install first via: curl -fsSL bit.ly/create-nodejs | sh"
    exit 1
fi

GEMINI="https://github.com/google-gemini/gemini-cli/releases/latest/download/gemini-cli-bundle.zip"
GEMINI_PREFIX="$LIB_DIR/gemini-cli"
GEMINI_TMP=$(mktemp -d)

curl -fsSL -o "$GEMINI_TMP/gemini.zip" "$GEMINI"
unzip -q "$GEMINI_TMP/gemini.zip" -d "$GEMINI_TMP/bundle"

sudo rm -rf "$GEMINI_PREFIX"
sudo mv "$GEMINI_TMP/bundle" "$GEMINI_PREFIX"
sudo chmod -R a+rX "$GEMINI_PREFIX"

sudo tee "$BIN_DIR/gemini" >/dev/null <<EOF
#!/bin/sh
exec node $GEMINI_PREFIX/gemini.js "\$@"
EOF
sudo chmod 0755 "$BIN_DIR/gemini"

rm -rf "$GEMINI_TMP"

"$BIN_DIR/gemini" --version
