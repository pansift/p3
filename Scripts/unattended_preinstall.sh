#!/usr/bin/env bash

# This script is intended for MSP use AND REQUIRES MODIFICATION 
# It is a "preinstall" script *but* assumes Pansift.app has been 
# copied to /Applications already *and* not opened yet. The MSP
# or IT owner will use their own staging mechanism to ensure the
# application bundle is present e.g. SFTP, SCP, FTP etc.

# You must update <BUCKET_UUID>, <INGEST_URL>, and <WRITE_TOKEN> in the script below.
# This must occur *before* Pansift.app is opened or else it will revert to the free 
# ZTP(Zero Touch Provisioning) with no control over bucket choice per agent and will 
# provision new buckets. You should have a specific bucket in mind if an MSP and 
# contact Pansift support for commercial shared/multi-agent buckets.

# THIS SCRIPT MUST BE RUN IN THE CONTEXT OF THE LOGGED IN USER AND NOT A SYSTEM OR HEADLESS ACCOUNT

# set -e
# set -vx
# script_name=$(basename "$0")

CURRENTDIR="$(pwd)"

function timenow {
	date "+%Y%m%dT%H%M%S%z"
}

echo "Running PanSift unattended_preinstall.sh at $(timenow) with..."
echo "Directory: $CURRENTDIR"

# Get the base config to help with set up which assumes Pansift.app is now there.
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

echo "Setting up custom Pansift.conf settings for automated claim"
#
# !!! REPLACE THE <BUCKET_UUID> with your bucket UUID also known as the Pansift UUID
# !!! REPLACE THE <INGEST_URL> with the full URL of "https://<UUID>.ingest.pansift.com"
# !!! REPLACE THE <WRITE_TOKEN> with the API token string
#######  ALL OF THE ABOVE CAN BE FOUND IN YOUR BUCKET SETTINGS #########
#
echo "<BUCKET_UUID>" > "$PANSIFT_PREFERENCES"/pansift_uuid.conf
echo "<INGEST_URL>" > "$PANSIFT_PREFERENCES"/pansift_ingest.conf
echo "<WRITE_TOKEN>" > "$PANSIFT_PREFERENCES"/pansift_token.conf
#
# !!! REPLACE THE ABOVE WITH YOUR SPECIFIC UUID, INGEST, AND TOKEN !!!
#

# This script has some overlap with the bootstrap script which is fine
# Bootstrap will still be run on first app run.

# Remove the interactive Internet app warning
echo "Unsetting flag on quarantine of app which requires user interaction..."
xattr -r -d com.apple.quarantine /Applications/Pansift.app

exit
