#!/usr/bin/env bash

#set -e
#set -vx
ingest=""
applescriptCode=""
source "$HOME"/Library/Preferences/Pansift/pansift.conf

pansift_ingest_file="$PANSIFT_PREFERENCES"/pansift_ingest.conf
if test -f "$pansift_ingest_file"; then
    line=$(head -n 1 $pansift_ingest_file)
    #echo $line
    ingest=$(echo -n "$line" | awk '{$1=$1;print}' | tr '[:upper:]' '[:lower:]' | tr -d '\r' | sed 's! !\\ !g')
		ingest_regex='https://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'

  if [[ $ingest =~ $ingest_regex ]]; then
    #echo "$uuid match"
    applescriptCode="display dialog \"$ingest\" buttons {\"OK\"} default button \"OK\" with title \"Ingest URL (Valid)\"" 
  else
    #echo "$uuid no match"
    applescriptCode="display dialog \"$ingest\" buttons {\"OK\"} default button \"OK\" with title \"Ingest URL (Invalid)\"" 
  fi 
else
  error="Please retrieve your PanSift Ingest URL via web account, restart ZTP, or ask an IT admin"
  #echo "$uuid no file"
  applescriptCode="display dialog \"$error\" buttons {\"OK\"} default button \"OK\" with title \"No Ingest URL File Found\"" 
fi

show=$(osascript -e "$applescriptCode");
