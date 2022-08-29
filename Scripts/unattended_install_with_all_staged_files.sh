#!/usr/bin/env bash

# This script is intended for deploying PanSift to multiple machines silently via automation
# such as with an MDM app or similar. It requires an Pansift.app and 

# THIS SCRIPT MUST BE RUN IN THE CONTEXT OF THE LOGGED IN USER NOT A SYSTEM OR HEADLESS ACCOUNT

#set -e
#set -vx
script_name=$(basename "$0")

if [[ ${#1} = 0 ]]; then
	echo "Usage: Pass the absolute and full path of the app bundle (inc. <name>.app) as the first argument."
	echo ""
	echo "Example: ./$script_name /tmp/Pansift.app 2>&1 | tee install.log"
	echo ""
	echo "Note: You will also need the pansift_uuid.conf, pansift_token.conf, and pansift_ingest.conf 
	echo "      files to be present in the same directory if pre-staging for a known claimed bucket.
	exit 0;
fi

DIR="$(dirname "$1")"
APP="$(basename "$1")"

function timenow {
  date "+%Y%m%dT%H%M%S%z"
}

echo "Running unattended at $(timenow) with..." 
echo "Directory: $DIR"
echo "App Bundle: $APP"

echo "Shutting down any existing Pansift.app instances and related telegraf"
# Shut down the current Pansift.app if there is one
if [[ $(pgrep -f Pansift.app) ]]; then
  pkill -KILL -f Pansift.app
fi
if [[ $(pgrep -f Pansift/telegraf-osx.conf) ]]; then
  pkill -KILL -f Pansift/telegraf-osx.conf
fi

# This script has some overlap with the bootstrap script which is fine
# Bootstrap will still be run on first app run if required.

# Get the base config to help with set up
echo "Getting basic configuration for directory creation..."
source "$DIR"/"$APP"/Contents/Resources/Preferences/pansift.conf

# Basic Configuration and then additional preferences files if present.
echo "Creating preferences directory if non-existent: $PANSIFT_PREFERENCES"
mkdir -p "$PANSIFT_PREFERENCES":/
echo "Copying additional prestaged configuration files if found from: $DIR"
if compgen -G "${DIR}/*.conf" > /dev/null; then
	rsync -aru "$DIR"/*.conf "$PANSIFT_PREFERENCES"
else
	echo "No additional pre-staged configuration files found in: $DIR"
fi

# Scripts and additional executables
echo "Creating scripts and plugins directory if non-existent: $PANSIFT_SCRIPTS" 
mkdir -p "$PANSIFT_SCRIPTS"
mkdir -p "$PANSIFT_SCRIPTS"/Plugins

# Logs, logs, logs
echo "Creating logs directory if non-existent: $PANSIFT_LOGS" 
mkdir -p "$PANSIFT_LOGS"

# PIDs and other flotsam
echo "Creating support directory if non-existent: $PANSIFT_LOGS" 
mkdir -p "$PANSIFT_SUPPORT"

# Mac OSX - copy across main app and files
echo "Copying application files to above directories (inc. /Applications/${APP})" 
rsync -aru "$DIR"/"$APP" /Applications
# scripts to ~/Library/Pansift
rsync -aru "$DIR"/"$APP"/Contents/Resources/Scripts/* "$PANSIFT_SCRIPTS"
# conf to ~/Library/Preferences/Pansift
rsync -aru "$DIR"/"$APP"/Contents/Resources/Preferences/*.conf "$PANSIFT_PREFERENCES"
# Telegraf Support
rsync -aru "$DIR"/"$APP"/Contents/Resources/Support/telegraf "$PANSIFT_SUPPORT"

# Remove the interactive Internet app warning
echo "Unsetting flag on quarantine of app which requires user interaction..." 
xattr -r -d com.apple.quarantine "$DIR"/"$APP"

# Do a similar once off like the bootstrap script
echo "Running PanSift first run of watcher script..." 
cd "$PANSIFT_SCRIPTS" && ./pansift -b &
disown 
sleep 5

# Open the app on the remote machine
echo "Open PanSift (PS) in menu bar" 
osascript -e "tell application \"Pansift.app\"" -e "activate" -e "end tell"
# "activate" takes focus but also issues a run whereas "launch" doesn't!
# osascript -e "tell application \"Pansift.app\"" -e "launch" -e "end tell"

exit
