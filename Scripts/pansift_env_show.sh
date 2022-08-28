#!/usr/bin/env bash

#set -e
#set -vx

source "$HOME"/Library/Preferences/Pansift/pansift.conf
url_regex='https://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
pansift_uuid_file="$PANSIFT_PREFERENCES"/pansift_uuid.conf
pansift_ingest_file="$PANSIFT_PREFERENCES"/pansift_ingest.conf
pansift_token_file="$PANSIFT_PREFERENCES"/pansift_token.conf
machine_uuid_file="$PANSIFT_PREFERENCES"/machine_uuid.conf

applescriptCode=""

if test -f "$pansift_uuid_file"; then
  pansift_uuid=$(head -n 1 "$pansift_uuid_file" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r')
else
  pansift_uuid="Missing pansift_uuid.conf file"
fi

if test -f "$machine_uuid_file"; then
  machine_uuid=$(head -n 1 "$machine_uuid_file" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r')
else
  machine_uuid="Missing machine_uuid.conf file"
fi

if test -f "$pansift_ingest_file"; then
  line=$(head -n 1 "$pansift_ingest_file")
  if [[ $line =~ $url_regex ]]; then
    pansift_ingest=$(echo -n "$line" | xargs | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r')
  else
		pansift_ingest="Problem with ingest URL format at: ${pansift_ingest_file}"
  fi
else
	 pansift_ingest="Missing pansift_ingest.conf file"
fi

if test -f "$pansift_token_file"; then
  # Token is case sensitive!!!
  pansift_token=$(head -n 1 "$pansift_token_file" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr -d '\r')
else
  pansift_token="Missing pansift_token.conf file"
fi

penv=$(echo "Agent Version: $PANSIFT_AGENT_VERSION")
penv=$(echo -e "${penv}\n$(echo "Bucket/PanSift UUID: $pansift_uuid")")
penv=$(echo -e "${penv}\n$(echo "Machine UUID: $machine_uuid")")
penv=$(echo -e "${penv}\n$(echo "Ingest URL: $pansift_ingest")")
penv=$(echo -e "${penv}\n$(echo "ZTP Token: $pansift_token")")
penv=$(echo -e "${penv}\n$(echo "Lighthouse: \"$PANSIFT_LIGHTHOUSE\"")")
penv=$(echo -e "${penv}\n$(echo "ICMP IPv4 Target: \"$PANSIFT_ICMP4_TARGET\"")")
penv=$(echo -e "${penv}\n$(echo "ICMP IPv6 Target: \"$PANSIFT_ICMP6_TARGET\"")")
penv=$(echo -e "${penv}\n$(echo "User: $USER")")
penv=$(echo -e "${penv}\n$(echo "Home: $HOME")")
penv=$(echo -e "${penv}\n$(echo "Path: $PATH")")
penv=$(echo -e "${penv}\n$(echo "Host: $HOSTNAME")")
penv=$(echo -e "${penv}\n$(echo "Preferences Path: \"$PANSIFT_PREFERENCES\"")")
penv=$(echo -e "${penv}\n$(echo "Application Scripts Path: \"$PANSIFT_SCRIPTS\"")")
penv=$(echo -e "${penv}\n$(echo "Logs Path: \"$PANSIFT_LOGS\"")")
penv=$(echo -e "${penv}\n$(echo "Application Support Path: \"$PANSIFT_SUPPORT\"")")
penv=$(echo "$penv" | tr -d '"')

if [ "$penv" ];then
	applescriptCode="display dialog \"$penv\" buttons {\"OK\"} default button \"OK\" with title \"PanSift ENV\"" 
else
	penv="No PanSift named or $PATH found in ENV"
	applescriptCode="display dialog \"$penv\" buttons {\"OK\"} default button \"OK\" with title \"PanSift ENV\"" 
fi

show=$(osascript -e "$applescriptCode");
