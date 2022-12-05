#!/usr/bin/env bash

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

echo "Shutting down any existing Pansift.app instances and related telegraf"
# Shut down the current Pansift.app if there is one
if [[ $(pgrep -f Pansift.app) ]]; then
  pkill -9 -f Pansift.app
fi
if [[ $(pgrep -f Pansift/telegraf-osx.conf) ]]; then
  pkill -9 -f Pansift/telegraf-osx.conf
fi

version=$(sw_vers -productVersion)
pansift_app_full_path="/Applications/Pansift.app"

if [[ $version =~ ^13 ]]; then
	echo "Important: Found macOS version $version (Ventura)"
	if [[ -d $pansift_app_full_path ]]; then
		echo "Existing Pansift.app so going to remove it to address Ventura: Privacy Policy Controls (PPPC)"
		echo "Rather than allow installer to fail (until Apple fix it)"
		sudo rm -rf $pansift_app_full_path
	fi 
else
	echo "Found macOS version: $version"
fi

exit
