#!/usr/bin/env bash

# This script is intended for MSPs or IT owners

# The MSP or IT owner needs to use their own staging mechanism
# to ensure the latest application bundle of "Pansift.app" is present
# in /Applications via SFTP, SCP, FTP etc. before running this script.

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

echo "Running PanSift $script_name at $(timenow) with..."
echo "Directory: $CURRENTDIR"

echo "Getting basic configuration from pre-staged Pansift.app in Applications..."
source /Applications/Pansift.app/Contents/Resources/Preferences/pansift.conf

echo "Running basic bootstrap to ensure latest versions of files and directories are present and used"
# Basic Configuration and then additional preferences files if present.
echo "Creating PanSift directories if non-existent..."
# Configuration and preferences files
mkdir -p "$PANSIFT_PREFERENCES"
# Scripts and additional executables
mkdir -p "$PANSIFT_SCRIPTS"
mkdir -p "$PANSIFT_SCRIPTS"/Plugins
# Logs, logs, logs
mkdir -p "$PANSIFT_LOGS"
# PIDs and other flotsam
mkdir -p "$PANSIFT_SUPPORT"
# Main scripts and settings possibly need updating...
# scripts to ~/Library/Pansift
rsync -aru /Applications/Pansift.app/Contents/Resources/Scripts/* "$PANSIFT_SCRIPTS"
# conf to ~/Library/Preferences/Pansift
rsync -aru /Applications/Pansift.app/Contents/Resources/Preferences/*.conf "$PANSIFT_PREFERENCES"
# Telegraf Support
rsync -aru /Applications/Pansift.app/Contents/Resources/Support/telegraf "$PANSIFT_SUPPORT"

# Remove the interactive Internet app warning
echo "Unsetting flag on quarantine of app which requires user interaction..."
xattr -r -d com.apple.quarantine /Applications/Pansift.app

# Open the app on the remote machine (or use as a post-install script)
echo "Open PanSift (PS) in menu bar"
osascript -e "tell application \"Pansift.app\"" -e "activate" -e "end tell"
# "activate" takes focus but also issues a run whereas "launch" doesn't!
# osascript -e "tell application \"Pansift.app\"" -e "launch" -e "end tell"

exit
