#!/usr/bin/env bash

read -r -d '' applescriptCode <<'EOF'
   set token to text returned of (display dialog "Enter your Pansift token?" default answer "")
   return token
EOF

token=$(osascript -e "$applescriptCode");

if [[ $token =~ ^[-_A-Z0-9a-z]{86}==$ ]]; then
    echo $token > $HOME/p3/pansift_token.conf
    $HOME/p3/pansift
else
    exit 1 
fi
