#!/usr/bin/env bash

source "$HOME"/Library/Preferences/Pansift/pansift.conf

read -r -d '' applescriptCode <<'EOF'
   set uuid to text returned of (display dialog "Enter your Pansift account UUID?" default answer "")
   return uuid
EOF

uuid=$(osascript -e "$applescriptCode");

if [[ $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
    echo $uuid > "$PANSIFT_PREFERENCES"/pansift_uuid.conf
    "$PANSIFT_SCRIPTS"/pansift    
else
    exit 1 
fi
