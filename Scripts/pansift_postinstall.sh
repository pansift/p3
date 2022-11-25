#!/usr/bin/env bash

# This script will remove the user interaction required to click yes 
# to opening the app from the Internet. The app has indeed been notarized 
# by Apple already. It will also move the correct files and create 
# the right directories.

# THIS SCRIPT MUST BE RUN IN THE CONTEXT OF THE LOGGED IN USER AND NOT A SYSTEM OR HEADLESS ACCOUNT

# set -e
# set -vx

script_name=$(basename "$0")

CURRENTDIR="$(pwd)"

function timenow {
	date "+%Y%m%dT%H%M%S%z"
}

echo "Running PanSift: $script_name at $(timenow) with..."
echo "Current Directory: $CURRENTDIR"

# Need a better way to get this check going on upgrades
login_items=$(osascript -e 'tell application "System Events" to get the name of every login item')
if [[ ! $login_items =~ Pansift ]]; then
  echo "Going to add Pansift as a Login Item for user $USER"
  osascript -e 'tell application "System Events" to make login item at end with properties {name: "Pansift",path:"/Applications/Pansift.app", hidden:false}'
else
  echo "Pansift is already a Login Item for user $USER"
fi


sleep 3 # Wait for slower disks to finish the Pansift app copy though this should not be necessary

# Remove the interactive Internet app warning (Not required if packaged and signed)
# echo "Unsetting flag on quarantine of app which requires user interaction..."
sudo xattr -r -d com.apple.quarantine /Applications/Pansift.app

# Add back in the Login Item in case this is a reinstall
# Can't use this as it asks for more permissions during the installer app, needs to live elsewhere
# osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Pansift.app", hidden:false, name:"Pansift"}'

currentuser=$(stat -f '%Su' /dev/console)
echo "Switch to user: $currentuser"
sudo -H -u $(stat -f "%Su" /dev/console) /bin/bash <<'END'
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

# Open the app on the remote machine (or use as a post-install script)
echo "Open PanSift (PS) in menu bar"

# Trying to use open only as the user in question
open /Applications/Pansift.app || exit 1

# osascript -e "tell application \"Pansift.app\"" -e "activate" -e "end tell"
# "activate" takes focus but also issues a run whereas "launch" doesn't!
# osascript -e "tell application \"Pansift.app\"" -e "launch" -e "end tell"

END

# Another option here outside of the END
# sudo -H -u $currentuser open /Applications/Pansift.app

exit
