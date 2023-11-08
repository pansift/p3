#!/usr/bin/env bash

#set -e
#set -vx
# source "$HOME"/Library/Preferences/Pansift/pansift.conf

osascript -e 'tell application "Terminal"' -e 'if (exists window 1) and not (busy of window 1) then' -e 'do script "tail -f -n100 \"$HOME\"/Library/Logs/Pansift/telegraf.log"' -e 'activate' -e 'else' -e 'do script "tail -f -n100 \"$HOME\"/Library/Logs/Pansift/telegraf.log"' -e 'activate' -e 'end if' -e 'end tell'
