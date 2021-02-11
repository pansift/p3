#!/usr/bin/env bash

source $HOME/.pansift/pansift.conf

# Don't kill anything, just check if Telegraf is already running as main script will restart anyway
tpid="$HOME/.pansift/telegraf.pid"
if [[ -f "$tpid" ]] && [[ $(pgrep "telegraf") ]]; then
  true 
else
  $HOME/.pansift/pansift  >/dev/null 2>&1
fi

echo "PanSift"
echo "---"
echo "Add an Issue Note | bash='$HOME/.pansift/pansift_annotate_update.sh' terminal=false"
echo "---"
ping -o -c2 -i1 -t5 $pansift_icmp4_target > /dev/null 2>&1 && echo "IPv4 Connectivity OK | color=green" || echo "No IPv4 Connecivity | color=red"
ping6 -o -c2 -i1 $pansift_icmp6_target > /dev/null 2>&1 && echo "IPv6 Connectivity OK | color=green" || echo "No IPv6 Connecivity | color=red"
echo "---"
echo "Restart PanSift Metrics | bash='$HOME/.pansift/pansift' terminal=false"
echo "Pansift UUID"
echo "-- Show UUID | bash='$HOME/.pansift/pansift_uuid_show.sh' terminal=false"
echo "-- Get UUID from Web | bash='$HOME/.pansift/pansift_webapp.sh' terminal=false"
echo "-- Reset/Update UUID | bash='$HOME/.pansift/pansift_uuid_update.sh' terminal=false"
echo "---"
echo "Config and Scripts"
echo "-- Update Agent Config"
echo "-- Update Scripts | bash='$HOME/.pansift/pansift_scripts_update.sh' terminal=false"
echo "---"
echo "Open Log | bash='tail -f -n50 $HOME/.pansift/telegraf.log'"
