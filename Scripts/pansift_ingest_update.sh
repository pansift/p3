#!/usr/bin/env bash

source "$HOME"/Library/Preferences/Pansift/pansift.conf

read -r -d '' applescriptCode <<'EOF'
	 set url_input to text returned of (display dialog "Enter your new PanSift Ingest URL." default answer linefeed with title "Update Ingest URL")
	 return url_input
EOF

url_input=$(osascript -e "$applescriptCode");
retval=$?
ingest=$(echo -n "$url_input" | awk '{$1=$1;print}' | tr '[:upper:]' '[:lower:]' | tr -d '\r' | sed 's! !\\ !g')
ingest_regex='https://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
if [ "${retval:-1}" -eq 1 ]; then
	exit 0
elif [[ $ingest =~ $ingest_regex ]]; then
	echo $ingest > "$PANSIFT_PREFERENCES"/pansift_ingest.conf
	"$PANSIFT_SCRIPTS"/pansift
else
	error="URL must be a valid HTTPs string."
	applescriptCode="display dialog \"$error\" buttons {\"OK\"} default button \"OK\" with title \"Error in URL Format\""
	show=$(osascript -e "$applescriptCode");
	exit 1 
fi
