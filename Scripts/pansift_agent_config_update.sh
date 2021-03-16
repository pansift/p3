#!/usr/bin/env bash

# Will also need a better way to deal with the install directory path rather than assuming and forcing $HOME

# Can not assume a user has git installed as it's either part of Xcode tools or a manual install.. so... curl!

# Note: GitHub serves "raw" pages with Cache-Control: max-age=300. That's specified in seconds, meaning the pages are intended to be cached for 5 minutes. You can see this if you open the Developer Tools in your web browser of choice before clicking the "Raw" button on GitHub.

source "$HOME"/Library/Preferences/Pansift/pansift.conf

bad_answers=()
preferences_location="https://raw.githubusercontent.com/pansift/p3/main/Preferences"
file_list=("pansift.conf" "telegraf-osx.conf")
# Note we don't want to update ourselves in case we break but what about script additions? Shame we can't use rsync?
mkdir -p "$PANSIFT_PREFERENCES"

for file in ${file_list[@]};
do
  curl_response=$(curl -s -o /dev/null -w "%{http_code}" -L "$preferences_location"/"$file" --stderr -)
  echo "$curl_response for $file"
  sleep 1
  if [[ $curl_response == 200 ]]; then
    curl -s "$preferences_location"/"$file" > "$PANSIFT_PREFERENCES"/"$file"
    # Ensure execution permissions
    chmod +x "$PANSIFT_PREFERENCES"/"$file"
  else
    bad_answers+=("Status: $curl_response for $file\n" )
  fi
done

if [[ ${#bad_answers[@]} == 0 ]];
then
  applescriptCode="display dialog \"Pansift updated agent configs successfully.\" buttons {\"OK\"} default button \"OK\""
  show=$(osascript -e "$applescriptCode");
else
  applescriptCode="display dialog \"Pansift failed some agent config updates:\n\n$bad_answers \" buttons {\"OK\"} default button \"OK\""
  show=$(osascript -e "$applescriptCode");
fi
