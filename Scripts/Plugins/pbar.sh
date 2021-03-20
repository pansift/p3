#!/usr/bin/env bash

source "$HOME"/Library/Preferences/Pansift/pansift.conf

# Don't kill anything, just check if Telegraf is already running as main script will restart anyway
  tpid="$PANSIFT_SUPPORT"/telegraf.pid
  if [[ -f "$tpid" ]] && [[ $(pgrep "telegraf") ]]; then
    true 
  else
    "$PANSIFT_SCRIPTS"/pansift -t >/dev/null 2>&1
  fi

echo "PS"
echo "---"
echo "Add an Issue / Note | bash='$PANSIFT_SCRIPTS/pansift_annotate_update.sh' terminal=false"
echo "---"
echo "Internet Connectivity"
ping -o -c2 -i1 -t5 $PANSIFT_ICMP4_TARGET > /dev/null 2>&1 && echo "IPv4 OK | color=green" || echo "No IPv4 Reachability | color=red"
ping6 -o -c2 -i1 $PANSIFT_ICMP6_TARGET > /dev/null 2>&1 && echo "IPv6 OK | color=green" || echo "No IPv6 Reachability | color=red"
echo "  ↺ Refresh | refresh=true"
echo "---"
echo "Dashboard"
echo "Web Login | bash='$PANSIFT_SCRIPTS/pansift_webapp.sh' terminal=false"
echo "---"
echo "Internals"
echo "UUID"
echo "-- Show | bash='$PANSIFT_SCRIPTS/pansift_uuid_show.sh' terminal=false"
echo "-- Update | bash='$PANSIFT_SCRIPTS/pansift_uuid_update.sh' terminal=false"
echo "-- Get UUID from Web | bash='$PANSIFT_SCRIPTS/pansift_webapp.sh -w' terminal=false"
echo "Token"
echo "-- Show | bash='$PANSIFT_SCRIPTS/pansift_token_show.sh' terminal=false"
echo "-- Update | bash='$PANSIFT_SCRIPTS/pansift_token_update.sh' terminal=false"
echo "-- Get Token from Web | bash='$PANSIFT_SCRIPTS/pansift_webapp.sh -w' terminal=false"
echo "Update Components"
echo "-- Scripts | bash='$PANSIFT_SCRIPTS/pansift_scripts_update.sh' terminal=false"
echo "-- Agent Config | bash='$PANSIFT_SCRIPTS/pansift_agent_config_update.sh' terminal=false"
echo "---"
echo "Restart Metrics | bash='$PANSIFT_SCRIPTS/pansift' terminal=false"
echo "---"
echo "Open Log | bash='$PANSIFT_SCRIPTS/telegraf_log_show.sh' terminal=false"
