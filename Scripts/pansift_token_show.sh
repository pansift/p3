#!/usr/bin/env bash

#set -e
#set -vx
applescriptCode=""

source "$HOME"/Library/Preferences/Pansift/pansift.conf

pansift_token_file=$PANSIFT_PREFERENCES/pansift_token.conf
if test -f "$pansift_token_file"; then
    line=$(head -n 1 $pansift_token_file)
    #echo $line
    token=$(echo -n "$line" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr -d '\r')

  if [[ $1 =~ ^[-_A-Z0-9a-z]{86}==$ ]]; then
  #echo "$token match"
    applescriptCode="display dialog \"$token\" buttons {\"OK\"} default button \"OK\"" 
  else
    #echo "$token no match"
    applescriptCode="display dialog \"$token\" buttons {\"OK\"} default button \"OK\"" 
  fi 
else
  token="Please retrieve token from PanSift web account or IT admin"
  applescriptCode="display dialog \"$token\" buttons {\"OK\"} default button \"OK\"" 
fi

show=$(osascript -e "$applescriptCode");

