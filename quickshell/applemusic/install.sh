#!/bin/bash
# One-time setup for the Apple Music bridge: registers the native-messaging
# host with Chromium and prints the extension ID to load unpacked.
set -e
here="$(cd "$(dirname "$0")" && pwd)"

id=$(python3 - "$here/extension/.pubkey" <<'EOF'
import sys, base64, hashlib
key = base64.b64decode(open(sys.argv[1]).read().strip())
print("".join(chr(ord("a") + int(c, 16)) for c in hashlib.sha256(key).hexdigest()[:32]))
EOF
)

chmod +x "$here/host.py"
for d in "$HOME/.config/chromium" "$HOME/.config/google-chrome" "$HOME/.config/BraveSoftware/Brave-Browser"; do
    [[ -d "$d" ]] || continue
    mkdir -p "$d/NativeMessagingHosts"
    cat > "$d/NativeMessagingHosts/dev.cachebag.applemusic.json" <<EOF
{
  "name": "dev.cachebag.applemusic",
  "description": "Quickshell Apple Music bridge",
  "path": "$here/host.py",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$id/"]
}
EOF
    echo "registered native host in $d"
done

cat <<EOF

Extension ID: $id
Load it once (it then stays installed in the profile):
  chromium → chrome://extensions → Developer mode → Load unpacked → $here/extension
EOF
