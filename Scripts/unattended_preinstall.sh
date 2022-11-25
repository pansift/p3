#!/usr/bin/env bash

# This script is intended for MSPs or IT owners 
# !!!!!! IT REQUIRES MODIFICATION BY YOU !!!!!!! 

# The MSP or IT owner needs to use their own staging mechanism
# to ensure the latest application bundle of "Pansift.app" is present
# in /Applications via SFTP, SCP, FTP etc. after running this script.
# and before running the follow on "unattended_postinstall.sh" script.

# You must update <BUCKET_UUID>, <INGEST_URL>, and <WRITE_TOKEN> in the script below.
# This must occur *before* Pansift.app is opened or else it will revert to the free 
# ZTP(Zero Touch Provisioning) with no control over bucket choice per agent and will 
# provision new random buckets per agent. You should have a specific bucket in mind 
# and be configuring it below with assistance from Pansift support 
# This script is for commercial shared/multi-agent buckets.

# *************************************************************************************************
# THIS SCRIPT MUST BE RUN IN THE CONTEXT OF THE LOGGED IN USER AND NOT A SYSTEM OR HEADLESS ACCOUNT
# *************************************************************************************************

# set -e
# set -vx

script_name=$(basename "$0")

CURRENTDIR="$(pwd)"

function timenow {
	date "+%Y%m%dT%H%M%S%z"
}
echo "Running PanSift $script_name at $(timenow) with..."
echo "Directory: $CURRENTDIR"

echo "Shutting down any existing Pansift.app instances and related telegraf"
# Shut down the current Pansift.app if there is one
if [[ $(pgrep -f Pansift.app) ]]; then
  pkill -9 -f Pansift.app
fi
if [[ $(pgrep -f Pansift/telegraf-osx.conf) ]]; then
  pkill -9 -f Pansift/telegraf-osx.conf
fi

currentuser=$(stat -f '%Su' /dev/console)
echo "Switch to user: $currentuser"
sudo -H -u $(stat -f "%Su" /dev/console) /bin/bash <<'END'
echo "HOME is $HOME"

# Basic Configuration and then additional preferences files if present.
echo "Creating PanSift Preferences directory if non-existent..."
# Configuration and preferences files
preferences="$HOME"/Library/Preferences/Pansift
mkdir -p $preferences

echo "Setting up custom Pansift.conf settings for automated claim if missing"
#
# !!! REPLACE THE <BUCKET_UUID> with your bucket UUID also known as the Pansift UUID
# !!! REPLACE THE <INGEST_URL> with the full URL of "https://<UUID>.ingest.pansift.com"
# !!! REPLACE THE <ZTP_TOKEN> (write token) with the API token string
# 
#######  ALL OF THE ABOVE CAN BE FOUND IN YOUR BUCKET SETTINGS #########
#
# WE ARE NOT GOING TO OVERWRITE IF FILE ALREADY THERE #
#
pansift_uuid_file="${preferences}/pansift_uuid.conf"
if [[ -f "$pansift_uuid_file" ]]; then
	echo "Existing ${pansift_uuid_file} so leaving it alone"
else
	echo "Writing to ${pansift_uuid_file}"
	echo "<BUCKET_UUID>" > "$pansift_uuid_file"
fi
pansift_ingest_file="${preferences}/pansift_ingest.conf"
if [[ -f "$pansift_ingest_file" ]]; then
	echo "Existing ${pansift_ingest_file} so leaving it alone"
else
	echo "Writing to ${pansift_ingest_file}"
	echo "<INGEST_URL>" > "$pansift_ingest_file"
fi
pansift_token_file="${preferences}/pansift_token.conf"
if [[ -f "$pansift_token_file" ]]; then
	echo "Existing ${pansift_token_file} so leaving it alone"
else
	echo "Writing to ${pansift_token_file}"
	echo "<ZTP_TOKEN>" > "$pansift_token_file"
fi
#
# !!! REPLACE THE ABOVE WITH YOUR SPECIFIC <BUCKET_UUID>, <INGEST_URL>, AND <ZTP_TOKEN> !!!
#

END

exit
