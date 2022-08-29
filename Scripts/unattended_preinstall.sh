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

echo "Shutting down any existing Pansift.app instances and related telegraf"
# Shut down the current Pansift.app if there is one
if [[ $(pgrep -f Pansift.app) ]]; then
  pkill -KILL -f Pansift.app
fi
if [[ $(pgrep -f Pansift/telegraf-osx.conf) ]]; then
  pkill -KILL -f Pansift/telegraf-osx.conf
fi

echo "Running PanSift unattended_preinstall.sh at $(timenow) with..."
echo "Directory: $CURRENTDIR"

# Basic Configuration and then additional preferences files if present.
echo "Creating PanSift Preferences directory if non-existent..."
# Configuration and preferences files
preferences="$HOME"/Library/Preferences/Pansift
mkdir -p $preferences

echo "Setting up custom Pansift.conf settings for automated claim"
#
# !!! REPLACE THE <BUCKET_UUID> with your bucket UUID also known as the Pansift UUID
# !!! REPLACE THE <INGEST_URL> with the full URL of "https://<UUID>.ingest.pansift.com"
# !!! REPLACE THE <WRITE_TOKEN> with the API token string
#######  ALL OF THE ABOVE CAN BE FOUND IN YOUR BUCKET SETTINGS #########
#
echo "<BUCKET_UUID>" > "$preferences"/pansift_uuid.conf
echo "<INGEST_URL>" > "$preferences"/pansift_ingest.conf
echo "<WRITE_TOKEN>" > "$preferences"/pansift_token.conf
#
# !!! REPLACE THE ABOVE WITH YOUR SPECIFIC UUID, INGEST, AND TOKEN !!!
#

exit
