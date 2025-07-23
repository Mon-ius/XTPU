#!/bin/dash

set +e

if [ -z "$1" ]; then
    echo "Usage: $0 <remote> <port>"
    echo "Example: $0 127.0.0.1 60022"
    exit 1
fi

_RHOST=127.0.0.1
_RPORT=60022
SNAME=reverse-ssh

RHOST="${1:-$_RHOST}"
RPORT="${2:-$_RPORT}"
SECRET="$HOME/.ssh/id_ed25519"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.$SNAME.plist"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.$SNAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/ssh</string>
        <string>-i</string>
        <string>$SECRET</string>
        <string>-NC</string>
        <string>-o</string>
        <string>GatewayPorts=true</string>
        <string>-o</string>
        <string>StrictHostKeyChecking=no</string>
        <string>-o</string>
        <string>ExitOnForwardFailure=yes</string>
        <string>-o</string>
        <string>ServerAliveInterval=10</string>
        <string>-o</string>
        <string>ServerAliveCountMax=3</string>
        <string>-R</string>
        <string>$RPORT:127.0.0.1:22</string>
        <string>$USER@$RHOST</string>
    </array>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>300</integer>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"
launchctl start "com.user.$SNAME"

echo "[SUCCESS] Reverse SSH tunnel created successfully."
echo "[INFO] Service name: com.user.$SNAME"
echo "[INFO] Plist location: $PLIST_PATH"
echo "[INFO] Remote host: $RHOST"
echo "[INFO] Remote port: $RPORT"
echo "[INFO] You can connect back using: ssh -p $RPORT $USER@$RHOST"
echo "[INFO] To check tunnel status: launchctl list | grep $SNAME"
echo "[INFO] To stop tunnel: launchctl stop com.user.$SNAME"
echo "[INFO] To remove tunnel: launchctl unload $PLIST_PATH && rm $PLIST_PATH"

# curl -fsSL https://raw.githubusercontent.com/Mon-ius/XTPU/refs/heads/main/darwin/create-reverse-ssh.sh | sh -s -- remote port