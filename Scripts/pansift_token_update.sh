#!/usr/bin/env bash

source "$HOME"/Library/Preferences/Pansift/pansift.conf

read -r -d '' applescriptCode <<'EOF'
   set token to text returned of (display dialog "Enter your Pansift token?" default answer "")
   return token
EOF

token=$(osascript -e "$applescriptCode");

if [[ $token =~ ^[-_A-Z0-9a-z]{86}==$ ]]; then
    echo $token > "$PANSIFT_PREFERENCES"/pansift_token.conf
    "$PANSIFT_SCRIPTS"/pansift
else
    exit 1 
fi
