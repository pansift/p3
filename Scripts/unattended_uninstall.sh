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
echo "PS: Parent process USER: $USER"
echo

echo "PS: Getting user password if required:"
sudo true

#currentUser=$(stat -f '%Su' /dev/console)
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
userHomeFolder=$(dscl . -read /users/${currentUser} NFSHomeDirectory | cut -d " " -f 2)
echo "PS: Running parts of script as logged in user: $currentUser"
echo "PS: User's home folder: $userHomeFolder"

# First, shut down the processes and stop PanSift from restarting if they continue.

echo "PS: Shutting down main PanSift.app and telegraf processes..."
sudo pkill -9 -f Pansift/telegraf
sudo pkill -9 -f Pansift.app
sudo pkill -9 -f Scripts/Pansift
echo "PS: Remove PanSift defaults if they exist..."
sudo defaults delete com.pansift.p3bar
echo "PS: Tell System Events to delete login item Pansift..."
sudo osascript -e 'tell application "System Events" to delete login item "Pansift"'

# We are not going to source any more as we might be root versus user
install_path="/Applications/Pansift.app"
preferences="$install_path"/Contents/Resources/Preferences/pansift.conf
if test -f "$preferences"; then
	echo "PS: Found original /Applications based pansift.conf preferences file..."
	true
	# source "$preferences"
else
	echo "PS: Can not find original /Applications based pansift.conf preferences file..."
	# We could exit but they have signalled their intent so let's continue.
	# exit 1
fi

sudo -H -u $currentUser userHomeFolder=$userHomeFolder /bin/bash <<'END'

pansift_uuid_file="$userHomeFolder"/Library/Preferences/Pansift/pansift_uuid.conf
if test -f "$pansift_uuid_file"; then
	echo "PS: pansift_uuid_file path: $pansift_uuid_file"
	line=$(head -n 1 $pansift_uuid_file)
	uuid=$(echo -n "$line" | xargs)
fi
pansift_token_file="$userHomeFolder"/Library/Preferences/Pansift/pansift_token.conf
if test -f "$pansift_token_file"; then
	echo "PS: pansift_token_file path: $pansift_token_file"
	line=$(head -n 1 $pansift_token_file)
	token=$(echo -n "$line" | xargs)
fi
pansift_ingest_file="$userHomeFolder"/Library/Preferences/Pansift/pansift_ingest.conf
if test -f "$pansift_ingest_file"; then
	echo "PS: pansift_ingest_file path: $pansift_ingest_file"
	line=$(head -n 1 $pansift_ingest_file)
	ingest=$(echo -n "$line" | xargs)
fi

echo "PS: =========================================================="
echo "PS:  Strongly recommend making a note of your Pansift settings"
echo "PS:  Bucket UUID: ${uuid}" 
echo "PS:  Write Token: ${token}" 
echo "PS:  Ingest URL: ${ingest}" 
echo "PS: =========================================================="

END

PANSIFT_PREFERENCES="$userHomeFolder"/Library/Preferences/Pansift
PANSIFT_SCRIPTS="$userHomeFolder"/Library/Application\ Scripts/Pansift
PANSIFT_LOGS="$userHomeFolder"/Library/Logs/Pansift
PANSIFT_SUPPORT="$userHomeFolder"/Library/Application\ Support/Pansift


if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	echo "Not supported on Linux yet" 
elif [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OSX
	# /Applications
	if [[ -d "/Applications/Pansift.app" ]]; then
		cd /Applications 
		sudo rm -rf ./Pansift.app
	fi
	# Sudoers Entry
	if [[ -f "/etc/sudoers.d/pansift" ]]; then
		cd /etc/sudoers.d/ && sudo rm pansift
	fi

	# sudo -H -u $currentUser PANSIFT_PREFERENCES="$PANSIFT_PREFERENCES" PANSIFT_SCRIPTS="$PANSIFT_SCRIPTS" PANSIFT_LOGS="$PANSIFT_LOGS" PANSIFT_SUPPORT="$PANSIFT_SUPPORT" /bin/bash <<'END'

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

	# END

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
