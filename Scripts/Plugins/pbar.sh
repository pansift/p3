#!/usr/bin/env bash

# NOTE: Default pbadr.sh runs every 60s
# Scenario where re-copying in the App after an uninstall but same App version

# so the bootstrap does not get run hence we need to run it.
if [[ ! -f "$HOME"/Library/Preferences/Pansift/pansift.conf ]]; then
 /Applications/Pansift.app/Contents/Resources/Scripts/bootstrap.sh "/Applications/Pansift.app"
fi

source "$HOME"/Library/Preferences/Pansift/pansift.conf
pansift_uuid_file="$PANSIFT_PREFERENCES"/pansift_uuid.conf

# Don't kill anything, just check if Telegraf is already running as main script will restart anyway
# We still need to address duplicate processes on some machines and "$PANSIFT_SUPPORT"/telegraf.pid
# isn't reliable...

# The App seems to run pbar.sh twice so we need to avert a race condition
# on the following pgrep which can launch 2 telegrafs in the "else"
pause=$(( ($RANDOM % 5) + 1 ))
sleep $pause # Important to get round pbar running twice on first open

if [[ $(pgrep -f Pansift/telegraf-osx.conf) ]]; then
	if [[ $(pgrep -f Pansift/telegraf-osx.conf | awk 'NR >= 2') ]]; then
		pgrep -f Pansift/telegraf-osx.conf | awk 'NR >= 2' | xargs -n1 kill -15 &>/dev/null
		# Sending -15 SIGTERM here rather than -9 SIGKILL to let graceful cleanup occur
		# Additionally we don't want any output from a failed kill in the UI
	else
		# echo "There is only 1 telegraf process"
		true
	fi
else
	# Nothing found so start telegraf via main pansift script
	"$PANSIFT_SCRIPTS"/pansift >/dev/null 2>&1 &
	disown -a
fi

# Scenario when after an uninstall and copying same version of Pansift.app
# that this file is missing on first iteration.. so let's touch it.
if [[ ! -f "$PANSIFT_LOGS"/telegraf.log ]]; then
	mkdir -p "$PANSIFT_LOGS"
	touch "$PANSIFT_LOGS"/telegraf.log
fi

agent_check() {
	logs=$(tail -n 3 "$PANSIFT_LOGS"/telegraf.log)
	log_msg="$(echo -n "$logs" | egrep -qi "\[agent\] error" || { echo -n 'Agent (OK) | color=green'; exit 0; }; echo -n "$logs" | egrep -i "\[agent\] error" | cut -d":" -f3 | awk '{print $0"| color=red"}')"
	echo "$log_msg"
}

echo "PS"
echo "---"
echo "About PanSift | bash='$PANSIFT_SCRIPTS/pansift_about.sh' terminal=false"
echo "---"
echo "Send Extra Information"
echo "Add Note or Issue | bash='$PANSIFT_SCRIPTS/pansift_annotate_update.sh' terminal=false"
echo "---"
echo "Reachability Status"
ping -o -c2 -i1 -t5 $PANSIFT_ICMP4_TARGET > /dev/null 2>&1 && echo "IPv4 (OK) | color=green" || echo "IPv4 (Issues) | color=red"
ping6 -o -c2 -i1 $PANSIFT_ICMP6_TARGET > /dev/null 2>&1 && echo "IPv6 (OK) | color=green" || echo "IPv6 (Issues) | color=orange"
agent_check
echo "  ↺ Refresh | refresh=true"
echo "---"
echo "Web Dashboard"
echo "Investigate | bash='$PANSIFT_SCRIPTS/pansift_webapp.sh' terminal=false"
echo "Claim Agent / Bucket | bash='$PANSIFT_SCRIPTS/pansift_webapp.sh' terminal=false"
echo "---"
echo "Internals"
echo "-- Show PS ENV | bash='$PANSIFT_SCRIPTS/pansift_env_show.sh' terminal=false"
echo "-- Bucket UUID"
echo "---- Show | bash='$PANSIFT_SCRIPTS/pansift_uuid_show.sh' terminal=false"
echo "---- Update | bash='$PANSIFT_SCRIPTS/pansift_uuid_update.sh' terminal=false"
echo "-- Write Token"
echo "---- Show | bash='$PANSIFT_SCRIPTS/pansift_token_show.sh' terminal=false"
echo "---- Update | bash='$PANSIFT_SCRIPTS/pansift_token_update.sh' terminal=false"
echo "-- Ingest URL"
echo "---- Show | bash='$PANSIFT_SCRIPTS/pansift_ingest_show.sh' terminal=false"
echo "---- Update | bash='$PANSIFT_SCRIPTS/pansift_ingest_update.sh' terminal=false"
echo "-- Config Update"
echo "---- Scripts | bash='$PANSIFT_SCRIPTS/pansift_scripts_update.sh' terminal=false"
echo "---- Agent Config | bash='$PANSIFT_SCRIPTS/pansift_agent_config_update.sh' terminal=false"
echo "-- Uninstall"
echo "---- Interactively | bash='$PANSIFT_SCRIPTS/uninstall.sh' terminal=true"
echo "-- ZTP"
echo "---- Restart | bash='$PANSIFT_SCRIPTS/pansift_restart_ztp.sh' terminal=false"
echo "Open Log | bash='$PANSIFT_SCRIPTS/telegraf_log_show.sh' terminal=false"
echo "---"
echo "Restart Metrics | bash='$PANSIFT_SCRIPTS/pansift' terminal=false"
echo "Push Machine Details | bash='$PANSIFT_SCRIPTS/pansift' param1=-b terminal=false"
# Restart metrics with -b will force the once off config and then take 60s to run normal metrics again.
