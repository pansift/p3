#!/usr/bin/env bash

#set -e
#set -vx
applescriptCode=""

source "$HOME"/Library/Preferences/Pansift/pansift.conf
penv=$("$PANSIFT_SCRIPTS"/pansift | tr -d '"')

if [ "$penv" ];then
	applescriptCode="display dialog \"$penv\" buttons {\"OK\"} default button \"OK\" with title \"PanSift ENV\"" 
else
	penv="No PanSift named or $PATH found in ENV"
	applescriptCode="display dialog \"$penv\" buttons {\"OK\"} default button \"OK\" with title \"PanSift ENV\"" 
fi

show=$(osascript -e "$applescriptCode");
