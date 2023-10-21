#!/usr/bin/env bash

source "$HOME"/Library/Preferences/Pansift/pansift.conf

read -r -d '' applescriptCode <<'EOF'
	 set token to text returned of (display dialog "Enter your new PanSift token." default answer linefeed with title "Update ZTP / Write Token")
	 return token
EOF

token=$(osascript -e "$applescriptCode");
retval=$?
if [ "${retval:-1}" -eq 1 ]; then
	exit 0
elif [[ $token =~ ^[-_A-Z0-9a-z]{86}==$ ]]; then
	echo $token > "$PANSIFT_PREFERENCES"/pansift_token.conf
	"$PANSIFT_SCRIPTS"/pansift
else
	error="Please remove all whitespace. Token is 86 character alphanumeric (with dashes) and ends with '=='"
	applescriptCode="display dialog \"$error\" buttons {\"OK\"} default button \"OK\" with title \"Error in Token Format\""
	show=$(osascript -e "$applescriptCode");
	exit 1 
fi
