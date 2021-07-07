#!/usr/bin/env bash

source "$HOME"/Library/Preferences/Pansift/pansift.conf
pansift_ingest_file="$PANSIFT_PREFERENCES"/pansift_ingest.conf
pansift_uuid_file="$PANSIFT_PREFERENCES"/pansift_uuid.conf
url_regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'

# Don't kill anything, just check if Telegraf is already running as main script will restart anyway
tpid="$PANSIFT_SUPPORT"/telegraf.pid
if [[ -f "$tpid" ]] && [[ $(pgrep "telegraf") ]]; then
	true 
else
	"$PANSIFT_SCRIPTS"/pansift -t >/dev/null 2>&1
fi

curl_user_agent() {
if test -f "$pansift_uuid_file"; then
  line=$(head -n 1 "$pansift_uuid_file")
  pansift_uuid=$(echo -n "$line" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r')
	curl_user_agent="pansift_"$pansift_uuid
else
  curl_user_agent="pansift_no_agent_or_uuid_available"
fi
}
curl_user_agent # Set the curl agent

db_check() {
  if test -f "$pansift_ingest_file"; then
    line=$(head -n 1 "$pansift_ingest_file")
    if [[ $line =~ $url_regex ]]; then
      pansift_ingest=$(echo -n "$line" | xargs | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r')
      db_code=$(curl -A "$curl_user_agent" --no-keepalive -k -s -o /dev/null -w "%{http_code}" "$pansift_ingest/health" --stderr -)
			db_code="${db_code:-$?}"
      if [[ $db_code == "200" ]]; then
        echo "DB (HTTP 200) | color=green"
      else
        echo "DB (HTTP $db_code) | color=red"
      fi
    else
			db_code="${db_code:-ingest_url_issue}"
      echo "DB ($db_code) | color=red"
    fi
  else
		db_code="${db_code:-missing_ingest_file}"
    echo "DB ($db_code) | color=red"
  fi
}

echo "PS"
echo "---"
echo "Add an Issue / Note | bash='$PANSIFT_SCRIPTS/pansift_annotate_update.sh' terminal=false"
echo "---"
echo "Reachability Status"
ping -o -c2 -i1 -t5 $PANSIFT_ICMP4_TARGET > /dev/null 2>&1 && echo "IPv4 (OK) | color=green" || echo "No IPv4 | color=red"
ping6 -o -c2 -i1 $PANSIFT_ICMP6_TARGET > /dev/null 2>&1 && echo "IPv6 (OK) | color=green" || echo "No IPv6 | color=orange"
db_check
echo "  ↺ Refresh | refresh=true"
echo "---"
echo "Web Dashboard"
echo "Investigate | bash='$PANSIFT_SCRIPTS/pansift_webapp.sh' terminal=false"
echo "Claim Agent | bash='$PANSIFT_SCRIPTS/pansift_webapp.sh' terminal=false"
echo "---"
echo "Internals"
echo "Bucket UUID"
echo "-- Show | bash='$PANSIFT_SCRIPTS/pansift_uuid_show.sh' terminal=false"
echo "-- Update | bash='$PANSIFT_SCRIPTS/pansift_uuid_update.sh' terminal=false"
echo "Token"
echo "-- Show | bash='$PANSIFT_SCRIPTS/pansift_token_show.sh' terminal=false"
echo "-- Update | bash='$PANSIFT_SCRIPTS/pansift_token_update.sh' terminal=false"
echo "Config Update"
echo "-- Scripts | bash='$PANSIFT_SCRIPTS/pansift_scripts_update.sh' terminal=false"
echo "-- Agent Config | bash='$PANSIFT_SCRIPTS/pansift_agent_config_update.sh' terminal=false"
echo "System"
echo "-- Restart ZTP | bash='$PANSIFT_SCRIPTS/pansift_restart_ztp.sh' terminal=false"
echo "-- Remove"
echo "---- Uninstall | bash='$PANSIFT_SCRIPTS/uninstall.sh' terminal=true"
echo "---"
echo "Restart Metrics | bash='$PANSIFT_SCRIPTS/pansift' terminal=false"
echo "---"
echo "Open Log | bash='$PANSIFT_SCRIPTS/telegraf_log_show.sh' terminal=false"
