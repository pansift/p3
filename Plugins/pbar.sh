#!/usr/bin/env bash

source $HOME/p3/pansift.conf

# Don't kill anything, just check if Telegraf is already running as main script will restart anyway
tpid="$HOME/p3/telegraf.pid"
if [[ -f "$tpid" ]] && [[ $(pgrep "telegraf") ]]; then
  true 
else
  $HOME/p3/pansift  >/dev/null 2>&1
fi

echo "PS"
echo "---"
echo "Add an issue note | bash='$HOME/p3/pansift_annotate_update.sh' terminal=false"
echo "---"
ping -o -c2 -i1 -t5 $pansift_icmp4_target > /dev/null 2>&1 && echo "IPv4 Connectivity OK | color=green" || echo "No IPv4 Connecivity | color=red"
ping6 -o -c2 -i1 $pansift_icmp6_target > /dev/null 2>&1 && echo "IPv6 Connectivity OK | color=green" || echo "No IPv6 Connecivity | color=red"
echo " ↺ Refresh | refresh=true"
echo "---"
echo "Restart PanSift Metrics | bash='$HOME/p3/pansift' terminal=false"
echo "---"
echo "UUID"
echo "-- Show UUID | bash='$HOME/p3/pansift_uuid_show.sh' terminal=false"
echo "-- Get UUID from Web | bash='$HOME/p3/pansift_webapp.sh' terminal=false"
echo "-- Reset/Update UUID | bash='$HOME/p3/pansift_uuid_update.sh' terminal=false"
echo "Token"
echo "-- Show Token | bash='$HOME/p3/pansift_token_show.sh' terminal=false"
echo "-- New Token | bash='$HOME/p3/pansift_webapp.sh'"
echo "-- Reset/Update UUID | bash='$HOME/p3/pansift_token_update.sh' terminal=false"
echo "---"
echo "Update Components"
echo "-- Agent Config | bash='$HOME/p3/pansift_agent_config_update.sh' terminal=false"
echo "-- Scripts | bash='$HOME/p3/pansift_scripts_update.sh' terminal=false"
echo "---"
echo "Log In / Web App | bash='$HOME/p3/pansift_webapp.sh'" # Needs a window reference hence won't work with terminal false
echo "Open Log | bash='tail -f -n50 $HOME/p3/telegraf.log'"
