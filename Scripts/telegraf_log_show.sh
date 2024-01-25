#!/usr/bin/env bash

#set -e
#set -vx
# source "$HOME"/Library/Preferences/Pansift/pansift.conf

# TODO: This could write a tail command in to someone's active terminal window session.
# Previous attempts at more comprehensive logic result in a problem with "busy" on Sonoma
# Currently, trying to simplify without overthinking?

open "$HOME"/Library/Logs/Pansift/telegraf.log

# osascript  \
# -e 'tell application "Terminal"' \
# 		-e 'if not (exists window 1) then reopen' \
# 		-e 'activate' \
# 		-e 'do script "tail -f -n100 \"$HOME\"/Library/Logs/Pansift/telegraf.log" in window 1' \
# -e 'end tell'
