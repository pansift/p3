#!/usr/bin/env bash

#set -e
#set -vx
# source "$HOME"/Library/Preferences/Pansift/pansift.conf

osascript  \
-e 'tell application "Terminal"' \
		-e 'activate' \
		-e 'delay 1' \
		-e 'if (exists window 1) and (busy of window 1) then' \
  	-e 'activate' \
  	-e 'do script "tail -f -n100 \"$HOME\"/Library/Logs/Pansift/telegraf.log"' \
	-e 'else if (exists window 1) and not (busy of window 1) then' \
		-e 'activate' \
		-e 'do script "tail -f -n100 \"$HOME\"/Library/Logs/Pansift/telegraf.log" in window 1' \
	-e 'else if not (exists window 1) then' \
		-e 'do script "tail -f -n100 \"$HOME\"/Library/Logs/Pansift/telegraf.log"' \
	-e 'else' \
		-e 'display alert "PanSift Error" message "PanSift could not open a Terminal window"' \
	-e 'end if' \
-e 'end tell'
