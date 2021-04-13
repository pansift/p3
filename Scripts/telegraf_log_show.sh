#!/usr/bin/env bash

#set -e
#set -vx
source "$HOME"/Library/Preferences/Pansift/pansift.conf

osascript -e 'tell application "Terminal"' -e 'if (exists window 1) and not busy of window 1 then' -e 'do script "tail -f -n50 \"$HOME\"/Library/Logs/Pansift/telegraf.log"' -e 'else' -e 'do script "tail -f -n50 \"$HOME\"/Library/Logs/Pansift/telegraf.log"' -e 'end if' -e 'activate' -e 'end tell'
