#!/usr/bin/env bash

# This script will remove the user interaction required to click yes 
# to opening the app from the Internet. The app has indeed been notarized 
# by Apple already. It will also move the correct files and create 
# the right directories.

# THIS SCRIPT MUST BE RUN IN THE CONTEXT OF THE LOGGED IN USER AND NOT A SYSTEM OR HEADLESS ACCOUNT

# set -e
# set -vx

scriptName=$(basename "$0")

currentDir="$(pwd)"

function timenow {
	date "+%Y%m%dT%H%M%S%z"
}

echo "Running PanSift: $scriptName at $(timenow) with..."
echo "Current Directory: $currentDir"

# currentuser=$(stat -f '%Su' /dev/console)
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )

# Login Items is not the best way for addressing a reinstall
# It also doesn't work well as it prompts the user to give permissions
# This asks for more permissions during the installer app, needs to live elsewhere?

#login_items=$(osascript -e 'tell application "System Events" to get the name of every login item')
#if [[ ! $login_items =~ Pansift ]]; then
#  echo "Going to add Pansift as a Login Item for user $currentUser"
#  sudo -H -u $currentUser osascript -e 'tell application "System Events" to make login item at end with properties {name: "Pansift",path:"/Applications/Pansift.app", hidden:false}'
#else
#  echo "Pansift is already a Login Item for user $currentUser"
#fi

sleep 3 # Wait for slower disks to finish the Pansift app copy though this should not be necessary but was in VM

# Remove the interactive Internet app warning (Not required if packaged and signed)
# echo "Unsetting flag on quarantine of app which requires user interaction..."
sudo xattr -r -d com.apple.quarantine /Applications/Pansift.app


echo "Switch to user: $currentUser"
sudo -H -u $currentUser /bin/bash <<'END'
echo "HOME is $HOME"

# Sync files as a backup incase the app boostrap can not.
echo "Setup PanSift dirs and files (if not already)"

# Source settings for this script
install_path="/Applications/Pansift.app"
source "$install_path"/Contents/Resources/Preferences/pansift.conf

# Configuration and preferences files
echo "PANSIFT_PREFERENCES path is $PANSIFT_PREFERENCES"
mkdir -p "$PANSIFT_PREFERENCES" || echo "Error: Could not create $PANSIFT_PREFERENCES"

# Scripts and additional executables
echo "PANSIFT_SCRIPTS path is $PANSIFT_SCRIPTS"
mkdir -p "$PANSIFT_SCRIPTS" || echo "Error: Could not create $PANSIFT_SCRIPTS"
mkdir -p "$PANSIFT_SCRIPTS"/Plugins || echo "Error: Could not create $PANSIFT_SCRIPTS/Plugins"

# Logs, logs, logs
echo "PANSIFT_LOGS path is $PANSIFT_LOGS"
mkdir -p "$PANSIFT_LOGS" || echo "Error: Could not create $PANSIFT_LOGS"

# PIDs and other flotsam
mkdir -p "$PANSIFT_SUPPORT" || echo "Error: Could not create $PANSIFT_SUPPORT"

# macOS
# Main scripts and settings need to get moved...
# scripts to ~/Library/Pansift
rsync -vvaru "$install_path"/Contents/Resources/Scripts/* "$PANSIFT_SCRIPTS"

# conf to ~/Library/Preferences/Pansift
rsync -vvaru "$install_path"/Contents/Resources/Preferences/*.conf "$PANSIFT_PREFERENCES"

# Telegraf Support
rsync -vvaru "$install_path"/Contents/Resources/Support/telegraf* "$PANSIFT_SUPPORT"

# osascript -e "tell application \"Pansift.app\"" -e "activate" -e "end tell"
# "activate" takes focus but also issues a run whereas "launch" doesn't!
# osascript -e "tell application \"Pansift.app\"" -e "launch" -e "end tell"

END

# Trying to use open only if the non-root or non-loginwindow user has a session

if [[ -z $currentUser || $currentUser == "root" || $currentUser == "loginwindow" ]]; then
	echo "Not going to open Pansift.app as no user logged in... is this an update only?"
else
	echo "Opening Pansift.app (PS) as user: $currentUser"
	sudo -H -u $currentUser open /Applications/Pansift.app
fi

exit
