#!/usr/bin/env bash

if [[ "$1" == "-w" ]]; then
	open "https://pansift.com?utm_source=ps_agent&utm_medium=web&utm_campaign=agent_about&utm_id=agent"
	exit
else
	source "$HOME"/Library/Preferences/Pansift/pansift.conf
	pansift_uuid_file=$PANSIFT_PREFERENCES/pansift_uuid.conf
	if test -f "$pansift_uuid_file"; then
		line=$(head -n 1 "$pansift_uuid_file")
		pansift_uuid=$(echo -n "$line" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r')
	fi
	open "https://pansift.com?utm_source=ps_agent&utm_medium=web&utm_campaign=agent_about&utm_id=${pansift_uuid}"
	exit 
fi
