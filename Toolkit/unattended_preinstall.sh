#!/usr/bin/env bash

# This script is intended for MSPs or IT savvy owner/administrators 
# !!!!!! IT REQUIRES MODIFICATION BY YOU !!!!!!! 
# It ensures that before the PKG installation there is config for a device 
# or multiple devices to use the same data bucket i.e. a shared bucket/multi-bucket.

# Intent is to run the PKG installer *after* this script.

# You must update <BUCKET_UUID>, <INGEST_URL>, and <ZTP_WRITE_TOKEN> everywhere in the script below.
# This must occur *before* Pansift.app is opened or else PanSift will revert to the free 
# ZTP(Zero Touch Provisioning) with no control over bucket choice per agent and will 
# provision new random buckets *per* agent. You should have a specific bucket in mind 
# and be configuring it below with assistance from PanSift support if required. 
# This script is for commercial shared/multi-agent buckets not standard UI agent/bucket claims.

# *************************************************************************************************
# THIS SCRIPT IS RUN AS ROOT BUT SWITCHES TO THE CONTEXT OF THE LOGGED IN USER USING SUDO ~LINE #48
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
# Technically this is not required (stopping) but it's cleaner if any of the 
# below is re-written to force an overwrite of configuration.
if [[ $(pgrep -f Pansift.app) ]]; then
	pkill -9 -f Pansift.app
fi
if [[ $(pgrep -f Pansift/telegraf-osx.conf) ]]; then
	pkill -9 -f Pansift/telegraf-osx.conf
fi

currentUser=$(stat -f '%Su' /dev/console)
echo "Switch to user: $currentUser"

sudo -H -u $currentUser /bin/bash <<'END'
echo "The HOME for $USER is: ${HOME:=<Unknown>}"

# Basic Configuration and then additional preferences files if present.
echo "Creating PanSift Preferences directory if non-existent..."
# Configuration and preferences files
preferences="$HOME"/Library/Preferences/Pansift
mkdir -p "$preferences"

echo "Setting up custom pansift.conf settings for automated claim if missing"
#
# !!! REPLACE THE <BUCKET_UUID> with your bucket UUID also known as the Pansift UUID
# !!! REPLACE THE <INGEST_URL> with the full URL of "https://<UUID>.ingest.pansift.com"
# !!! REPLACE THE <ZTP_WRITE_TOKEN> (write token) with the API token string
# 
#######  ALL OF THE ABOVE CAN BE FOUND IN YOUR BUCKET SETTINGS #########
#
# WE ARE NOT GOING TO OVERWRITE IF FILE ALREADY THERE #
# AMEND SCRIPT FOR OVERWRITING SETTINGS ON BOTH EXISTING AND NEW INSTALLS #
#
pansift_uuid_file="${preferences}/pansift_uuid.conf"
if [[ -f "$pansift_uuid_file" ]]; then
	echo "Existing ${pansift_uuid_file} so leaving it alone"
	# If you want to overwrite, comment out above and uncomment below
	# echo "Writing over existing: ${pansift_uuid_file}"
	# echo "<BUCKET_UUID>" > "$pansift_uuid_file"
else
	echo "Writing to ${pansift_uuid_file}"
	echo "<BUCKET_UUID>" > "$pansift_uuid_file"
fi
pansift_ingest_file="${preferences}/pansift_ingest.conf"
if [[ -f "$pansift_ingest_file" ]]; then
	echo "Existing ${pansift_ingest_file} so leaving it alone"
	# If you want to overwrite, comment out above and uncomment below
	# echo "Writing over existing: ${pansift_ingest_file}"
	# echo "<INGEST_URL>" > "$pansift_ingest_file"
else
	echo "Writing to ${pansift_ingest_file}"
	echo "<INGEST_URL>" > "$pansift_ingest_file"
fi
pansift_token_file="${preferences}/pansift_token.conf"
if [[ -f "$pansift_token_file" ]]; then
	echo "Existing ${pansift_token_file} so leaving it alone"
	# If you want to overwrite, comment out above and uncomment below
	# echo "Writing over existing: ${pansift_token_file}"
	# echo "<ZTP_WRITE_TOKEN>" > "$pansift_token_file"
else
	echo "Writing to ${pansift_token_file}"
	echo "<ZTP_WRITE_TOKEN>" > "$pansift_token_file"
fi
#
# !!! REPLACE THE ABOVE WITH YOUR SPECIFIC <BUCKET_UUID>, <INGEST_URL>, AND <ZTP_WRITE_TOKEN> !!!
# !!! The <INGEST_URL> normally looks like "https://<BUCKET_UUID>.ingest.pansift.com"
#

END

# If this is used accidentally on existing installs, re-open the app as we shut it down 
# at the start. Open only if the non-root or non-loginwindow user has a session, otherwise
# an existing install should open on user login.

pansift_application="/Applications/Pansift.app"

if [[ -d "$pansift_application" ]]; then
	if [[ -z $currentUser || $currentUser == "root" || $currentUser == "loginwindow" ]]; then
		echo "Not going to open Pansift.app as no relevant user: $currentUser logged in... is this an update only?"
	else
		echo "Opening Pansift.app (PS) as user: $currentUser"
		sudo -H -u $currentUser open /Applications/Pansift.app
	fi
else
	echo "No existing PanSift application found in /Applications, exiting..."
fi

exit
