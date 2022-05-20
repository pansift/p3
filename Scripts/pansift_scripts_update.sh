#!/usr/bin/env bash

# This is shonky until better RSYNC or formal update method.

# Can not assume a user has git installed as it's either part of Xcode tools or a manual install.. so... curl!

# Note: GitHub serves "raw" pages with Cache-Control: max-age=300. That's specified in seconds, meaning the pages are intended to be cached for 5 minutes. You can see this if you open the Developer Tools in your web browser of choice before clicking the "Raw" button on GitHub.

source "$HOME"/Library/Preferences/Pansift/pansift.conf

bad_answers=()
scripts_location="https://raw.githubusercontent.com/pansift/p3/main/Scripts"
file_list=("ztp.sh" "pansift_agent_config_update.sh" "pansift_webapp.sh" "pansift_ingest_show.sh" "pansift_token_show.sh" "pansift_uuid_show.sh" "pansift_ingest_update.sh" "pansift_token_update.sh" "pansift_uuid_update.sh" "pansift_annotate_update.sh" "osx_default_script.sh" "uninstall.sh" "telegraf_log_show.sh")
# Note we don't want to update ourselves in case we break but what about script additions? Shame we can't use rsync?
mkdir -p "$PANSIFT_PREFERENCES"

for file in ${file_list[@]};
do
	curl_response=$(curl -s -o /dev/null -w "%{http_code}" -L "$scripts_location"/"$file" --stderr -)
	echo "$curl_response for $file"
	sleep 1
	if [[ $curl_response == 200 ]]; then
		curl -s "$scripts_location"/"$file" > "$PANSIFT_SCRIPTS"/"$file"
		# Ensure execution permissions
    chmod +x "$PANSIFT_SCRIPTS"/"$file"
	else
		bad_answers+=("Status: $curl_response for $file\n" )
	fi
done

if [[ ${#bad_answers[@]} == 0 ]];
then
	applescriptCode="display dialog \"Pansift updated all scripts successfully.\" buttons {\"OK\"} default button \"OK\""
	show=$(osascript -e "$applescriptCode");
	"$PANSIFT_SCRIPTS"/pansift &
	disown
else 
	applescriptCode="display dialog \"Pansift failed some updates with:\n\n$bad_answers \" buttons {\"OK\"} default button \"OK\""
	show=$(osascript -e "$applescriptCode");
fi
