#!/usr/bin/env bash

source "$HOME"/Library/Preferences/Pansift/pansift.conf

# Configuration and preferences files
#PANSIFT_PREFERENCES="$HOME"/Library/Preferences/Pansift
#export PANSIFT_PREFERENCES="$PANSIFT_PREFERENCES"

# Scripts and additional executables
#PANSIFT_SCRIPTS="$HOME"/Library/Application\ Scripts/Pansift
#export PANSIFT_SCRIPTS="$PANSIFT_SCRIPTS"

# Logs, logs, logs
#PANSIFT_LOGS="$HOME"/Library/Logs/Pansift
#export PANSIFT_LOGS="$PANSIFT_LOGS"

# PIDs and other flotsam
#PANSIFT_SUPPORT="$HOME"/Library/Application\ Support/Pansift
#export PANSIFT_SUPPORT="$PANSIFT_SUPPORT"

# Don't kill anything, just check if Telegraf is already running as main script will restart anyway
tpid="$PANSIFT_SUPPORT"/telegraf.pid
if [[ -f "$tpid" ]] && [[ $(pgrep "telegraf") ]]; then
  true 
else
  "$PANSIFT_SCRIPTS"/pansift  >/dev/null 2>&1
fi

echo "PS"
echo "---"
echo "Add an issue note | bash='$PANSIFT_SCRIPTS/pansift_annotate_update.sh' terminal=false"
echo "---"
ping -o -c2 -i1 -t5 $PANSIFT_ICMP4_TARGET > /dev/null 2>&1 && echo "IPv4 Connectivity OK | color=green" || echo "No IPv4 Connecivity | color=red"
ping6 -o -c2 -i1 $PANSIFT_ICMP6_TARGET > /dev/null 2>&1 && echo "IPv6 Connectivity OK | color=green" || echo "No IPv6 Connecivity | color=red"
echo " ↺ Refresh | refresh=true"
echo "---"
echo "Restart PanSift Metrics | bash='$PANSIFT_SCRIPTS/pansift' terminal=false"
echo "---"
echo "UUID"
echo "-- Show | bash='$PANSIFT_SCRIPTS/pansift_uuid_show.sh' terminal=false"
echo "-- Get UUID from Web | bash='$PANSIFT_SCRIPTS/pansift_webapp.sh' terminal=false"
echo "-- Reset/Update | bash='$PANSIFT_SCRIPTS/pansift_uuid_update.sh' terminal=false"
echo "Token"
echo "-- Show | bash='$PANSIFT_SCRIPTS/pansift_token_show.sh' terminal=false"
echo "-- Get Token from Web | bash='$PANSIFT_SCRIPTS/pansift_webapp.sh'"
echo "-- Reset/Update | bash='$PANSIFT_SCRIPTS/pansift_token_update.sh' terminal=false"
echo "---"
echo "Update Components"
echo "-- Agent Config | bash='$PANSIFT_SCRIPTS/pansift_agent_config_update.sh' terminal=false"
echo "-- Scripts | bash='$PANSIFT_SCRIPTS/pansift_scripts_update.sh' terminal=false"
echo "---"
echo "Log In / Web App | bash='$PANSIFT_SCRIPTS/pansift_webapp.sh'" # Needs a window reference hence won't work with terminal false
echo "Open Log | bash='tail -f -n50 $PANSIFT_LOGS/telegraf.log'"
