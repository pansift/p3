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
echo "Directory: $CURRENTDIR"

# Remove the interactive Internet app warning (Not required if packaged and signed)
# echo "Unsetting flag on quarantine of app which requires user interaction..."
# xattr -r -d com.apple.quarantine /Applications/Pansift.app

# Add back in the Login Item in case this is a reinstall
# Can't use this as it asks for more permissions during the installer app 
# osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Pansift.app", hidden:false, name:"Pansift"}'

# Open the app on the remote machine (or use as a post-install script)
echo "Open PanSift (PS) in menu bar"
osascript -e "tell application \"Pansift.app\"" -e "activate" -e "end tell"
# "activate" takes focus but also issues a run whereas "launch" doesn't!
# osascript -e "tell application \"Pansift.app\"" -e "launch" -e "end tell"

exit
