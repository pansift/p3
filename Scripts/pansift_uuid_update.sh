#!/usr/bin/env bash

source "$HOME"/Library/Preferences/Pansift/pansift.conf

read -r -d '' applescriptCode <<'EOF'
	 set uuid to text returned of (display dialog "Enter your new Pansift Bucket UUID" default answer "" with title "Update Bucket UUID")
	 return uuid
EOF

uuid=$(osascript -e "$applescriptCode");
retval=$?
if [ "${retval:-1}" -eq 1 ]; then
	exit 0
elif [[ $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
	echo $uuid > "$PANSIFT_PREFERENCES"/pansift_uuid.conf
	"$PANSIFT_SCRIPTS"/pansift -b 
else
	error="Please remove all whitespace. UUID is a hexadecimal string with {8}-{4}-{4}-{4}-{12} characters separated by dashes. Example only: 4d41908c-a1b6-4ab5-af81-e600ee7c93ac"
	applescriptCode="display dialog \"$error\" buttons {\"OK\"} default button \"OK\" with title \"Error in Token Format\""
	show=$(osascript -e "$applescriptCode");
	exit 1 
fi
