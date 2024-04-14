#!/usr/bin/env bash

#set -e
#set -vx

# Moving things to the right places :)
# Being super verbose and as careful as can be with "rm"

CURRENTDIR="$(pwd)"
SCRIPT_NAME=$(basename "$0")

function timenow {
  date "+%Y%m%dT%H%M%S%z"
}

echo "PS: Running PanSift: $SCRIPT_NAME at $(timenow) with..."
echo "PS: Current Directory: $CURRENTDIR"

# currentUser=$(stat -f '%Su' /dev/console)
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
echo "PS: Running as user: $currentUser"

# sudo -H -u $(stat -f "%Su" /dev/console) /bin/bash <<'END'
# END

# Note: Do we need the above if running as root and no logged in user identified? This
# means it will potentially leave configuration, logs, and support files if not the
# targeted user as $HOME will be root home not the active user $HOME ?

# Source settings for this script
install_path="/Applications/Pansift.app"

preferences="$install_path"/Contents/Resources/Preferences/pansift.conf
if test -f "$preferences"; then
	source "$preferences"
else
	echo "PS: Can not find pansift.conf preferences file... cleaning up and stopping PanSift anyway"
fi

echo "PS: Getting user password if required:"
sudo true

pansift_uuid_file="$PANSIFT_PREFERENCES"/pansift_uuid.conf
if test -f "$pansift_uuid_file"; then
	line=$(head -n 1 $pansift_uuid_file)
	uuid=$(echo -n "$line" | xargs)
fi
pansift_token_file=$PANSIFT_PREFERENCES/pansift_token.conf
if test -f "$pansift_token_file"; then
	line=$(head -n 1 $pansift_token_file)
	token=$(echo -n "$line" | xargs)
fi
pansift_ingest_file="$PANSIFT_PREFERENCES"/pansift_ingest.conf
if test -f "$pansift_ingest_file"; then
	line=$(head -n 1 $pansift_ingest_file)
	ingest=$(echo -n "$line" | xargs)
fi

echo "PS: =========================================================="
echo "PS:  Strongly recommend making a note of your Pansift settings"
echo "PS:  Bucket UUID: ${uuid}" 
echo "PS:  Write Token: ${token}" 
echo "PS:  Ingest URL: ${ingest}" 
echo "PS: =========================================================="
echo

sudo pkill -9 -f Pansift/telegraf
sudo pkill -9 -f Pansift.app
sudo defaults delete com.pansift.p3bar
# The osascript looks for extra permissions in the GUI
sudo osascript -e 'tell application "System Events" to delete login item "Pansift"'

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	echo "Not supported on Linux yet" 
elif [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OSX
	# /Applications
	if [[ -d "/Applications/Pansift.app" ]]; then
		cd /Applications 
		sudo rm -rf ./Pansift.app
	fi
	# Scripts to Trash
	if [[ -d "$PANSIFT_SCRIPTS" ]]; then
		cd "$PANSIFT_SCRIPTS" && sudo rm -rf ../Pansift/*
		cd .. && sudo rmdir ./Pansift
	fi
	# Conf files
	if [[ -d "$PANSIFT_PREFERENCES" ]]; then
		if [[ -f "$PANSIFT_PREFERENCES"/pansift_token.conf ]]; then
			sudo rm "$PANSIFT_PREFERENCES"/pansift_token.conf 
		fi
		cd "$PANSIFT_PREFERENCES" && sudo rm -rf ../Pansift/*
		cd .. && sudo rmdir ./Pansift
	fi
	# Logs
	if [[ -d "$PANSIFT_LOGS" ]]; then
		cd "$PANSIFT_LOGS" && sudo rm -rf ../Pansift/*
		cd .. && sudo rmdir ./Pansift
	fi
	# Telegraf Support
	if [[ -d "$PANSIFT_SUPPORT" ]]; then
		cd "$PANSIFT_SUPPORT" && sudo rm -rf ../Pansift/*
		cd .. && sudo rmdir ./Pansift
	fi
  # Sudoers Entry
  if [[ -f "/etc/sudoers.d/pansift" ]]; then
    cd /etc/sudoers.d/ && sudo rm pansift
  fi
elif [[ "$OSTYPE" == "cygwin" ]]; then
	# POSIX compatibility layer and Linux environment emulation for Windows
	echo "Not supported on Cygwin yet" 
elif [[ "$OSTYPE" == "msys" ]]; then
	# Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
	echo "Not supported on MinGW yet."
elif [[ "$OSTYPE" == "win32" ]]; then
	# I'm not sure this can happen.
	echo "Not supported on Windows yet"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
	echo "Not supported on FreeBSD yet."
	# ...
else
	echo "Not supported on this platform yet"
fi

sudo pkgutil --forget com.pansift.p3bar

#launchctl unload -w ~/Library/LaunchAgents/com.pansift.p3bar
# Need to find where the launchagent went in Big Sur?

echo "PS: =========================================================="
echo "PS: Check Applications and move Pansift to Trash if requried."
echo "PS: Log in to https://pansift.com to request data deletion, "
echo "PS: or ask your administrator / managed service provider."
echo "PS: Note: Only Pansift admins can request web data deletions!"
echo "PS: =========================================================="

exit
