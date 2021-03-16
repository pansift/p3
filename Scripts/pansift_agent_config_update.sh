#!/usr/bin/env bash

# Will also need a better way to deal with the install directory path rather than assuming and forcing $HOME

# Can not assume a user has git installed as it's either part of Xcode tools or a manual install.. so... curl!

# Note: GitHub serves "raw" pages with Cache-Control: max-age=300. That's specified in seconds, meaning the pages are intended to be cached for 5 minutes. You can see this if you open the Developer Tools in your web browser of choice before clicking the "Raw" button on GitHub.

source "$HOME"/Library/Preferences/Pansift/pansift.conf

host="https://raw.githubusercontent.com/pansift/p3/main/Preferences/telegraf-osx.conf"
curl_response=$(curl -s -o /dev/null -w "%{http_code}" -L "$host" --stderr -)

if [[ $curl_response == 200 ]]; then

  curl -s https://raw.githubusercontent.com/pansift/p3/main/Preferences/telegraf-osx.conf > "$PANSIFT_PREFERENCES"/telegraf-osx.conf

  applescriptCode="display dialog \"Updated agent config with HTTP status code $curl_response.\" buttons {\"OK\"} default button \"OK\""
  show=$(osascript -e "$applescriptCode");
else
  applescriptCode="display dialog \"Can not reach repository with HTTP error code $curl_response\" buttons {\"OK\"} default button \"OK\""
  show=$(osascript -e "$applescriptCode");

fi

