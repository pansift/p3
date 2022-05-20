#!/usr/bin/env bash

source "$HOME"/Library/Preferences/Pansift/pansift.conf

read -r -d '' applescriptCode <<'EOF'
set uuid to text returned of (display dialog "Enter a brief note on an issue. The time and host details will be submitted automatically." default answer linefeed with title "PanSift User Comments / Notes")
return uuid
EOF

note=$(osascript -e "$applescriptCode");

remove_chars () {
	read data
	newdata=$(echo -n "$data" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr -d '\r' | tr -d '"')
	echo -n $newdata
}

note=$(echo -n "$note" | remove_chars)
if [ -n "$note" ]; then
	fieldset=$(echo -n "note=\"$note\"") 
	measurement="pansift_osx_annotations"
	timestamp=$(date +%s)000000000
	echo "$measurement $fieldset $timestamp" >> "$PANSIFT_LOGS"/pansift_annotations.log
	exit 0 
else
	exit 0
fi
