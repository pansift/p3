#!/usr/bin/env bash

#set -e
#set -vx
applescriptCode=""
source "$HOME"/Library/Preferences/Pansift/pansift.conf

applescriptCode='tell application "Terminal" to do script "tail -f -n50 \"$HOME\"/Library/Logs/Pansift/telegraf.log" & activate & return'

show=$(osascript -e "$applescriptCode");

