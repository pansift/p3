#!/usr/bin/env bash

#set -e
#set -vx
uuid=""
applescriptCode=""
source "$HOME"/Library/Preferences/Pansift/pansift.conf

pansift_uuid_file="$PANSIFT_PREFERENCES"/pansift_uuid.conf
if test -f "$pansift_uuid_file"; then
    line=$(head -n 1 $pansift_uuid_file)
    #echo $line
    uuid=$(echo -n "$line" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r' | sed 's! !\\ !g')

  if [[ $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
    #echo "$uuid match"
    applescriptCode="display dialog \"$uuid\" buttons {\"OK\"} default button \"OK\"" 
  else
    #echo "$uuid no match"
    applescriptCode="display dialog \"$uuid\" buttons {\"OK\"} default button \"OK\"" 
  fi 
else
  uuid="Please retrieve from PanSift UUID via web account or IT admin"
  #echo "$uuid no file"
  applescriptCode="display dialog \"$uuid\" buttons {\"OK\"} default button \"OK\"" 
fi


show=$(osascript -e "$applescriptCode");

