#!/usr/bin/env bash

# THIS SCRIPT MUST BE RUN IN THE CONTEXT OF THE LOGGED IN USER AND NOT A SYSTEM OR HEADLESS ACCOUNT

# set -e
# set -vx
scriptName=$(basename "$0")

currentDir="$(pwd)"

function timenow {
	date "+%Y%m%dT%H%M%S%z"
}
echo "PS: Running PanSift: $scriptName at $(timenow) with..."
echo "PS: Current Directory: $currentDir"

echo "PS: Shutting down any existing Pansift.app instances and related telegraf"
# Shut down the current Pansift.app if there is one
if [[ $(pgrep -f Pansift.app) ]]; then
	sudo pkill -9 -f Pansift.app
fi
if [[ $(pgrep -f Pansift/telegraf-osx.conf) ]]; then
	sudo pkill -9 -f Pansift/telegraf-osx.conf
fi

product_version=$(sw_vers -productVersion)
product_mainline=$(echo -n "$product_version" | cut -d'.' -f1 | xargs)
product_sub_version=$(echo -n "$product_version" | cut -d'.' -f2 | xargs)

if [[ $product_version =~ ^13 ]]; then
	echo "PS: Important: Found macOS product_version $product_version (Ventura)"
	if [[ -d /Applications/Pansift.app ]]; then
		echo "PS: Existing Pansift.app so going to remove it to address Ventura: Privacy Policy Controls (PPPC)"
		echo "PS: Rather than allow installer to fail (until Apple fix it!)"
		cd /Applications
		sudo rm -rf Pansift.app
	else
		echo "PS: No existing Pansift.app found in /Applications so continuing as per normal."
	fi 
else
	echo "PS: Found macOS product_version: $product_version"
fi

if [ $product_mainline -ge 14 ] && [ $product_sub_version -ge 4 ]; then
	echo "PS: Important: Found macOS product_version $product_version (Sonoma 14.4 or above)"
	echo "PS: For macOS $product_version we need sudoers for wdutil info due to airport CLI deprecation"
fi
# We will add the sudoers from agent 0.6.7 onwards so if the user upgrades we can still get Wi-Fi commands
# without having to mandate a reinstall of the agent post macOS 14.4 upgrades in the future.

echo "PS: Irrespective of macOS $product_version we need sudoers for future wdutil info due to airport CLI deprecation"

function add_to_sudoers() {
	echo "$1 ALL=NOPASSWD:/usr/bin/wdutil info #pansift" | sudo EDITOR="tee -a" visudo -f /etc/sudoers.d/pansift
}

# Check for PanSift sudoers entry and also targeted user account
currentUser=$(stat -f '%Su' /dev/console)
if test -f /etc/sudoers.d/pansift; then
	echo "PS: PanSift sudoers File already exists."
	grep_configline="$currentUser ALL=NOPASSWD:\/usr\/bin\/wdutil info #pansift"
	# grep_command=$(grep -ic "$grep_configline" /etc/sudoers.d/pansift)
	if grep -i "$grep_configline" /etc/sudoers.d/pansift; then
		echo "PS: Already have a sudoers entry for wdutil"
	else
		echo "PS: Can not find sudoers entry for wdutil"
		echo "PS: Adding #pansift sudoers entry for wdutil"
		add_to_sudoers "$currentUser"
	fi
else
	echo "PS: No PanSift sudoers file, adding one including an entry for wdutil info for $currentUser only"
	# sudo touch /etc/sudoers.d/pansift
	add_to_sudoers "$currentUser"
fi

exit
