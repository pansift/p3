#!/usr/bin/env bash

# TO be run as root. Expects a logged in user at the time.

# set -e
# set -x

verboseMode=1
scriptName=$(basename "$0")
currentDir="$(pwd)"
scriptVersion="v0.2"


#################
# Functions #
#################

function verify_root_user()
{
	# check we are running as root
	if [[ $(id -u) -ne 0 ]]; then
		/bin/echo "PS: ERROR: This script must be run as root **EXITING**"
		exit 1
	fi

}

#This function exits the script, deleting the temp files. first argument is the exit code, second argument is the message reported.
#example: cleanup_and_exit 1 "Download Failed."
function cleanup_and_exit()
{
	/bin/echo "${2}"
	# rm_if_exists "$tmpDir"
	/bin/kill "$caffeinatepid" > /dev/null 2>&1
	exit "$1"
}

# Prevent the computer from sleeping while this is running, capture the PID of caffeinate so we can kill it in our exit function
function no_sleeping()
{

	/usr/bin/caffeinate -d -i -m -u &
	caffeinatepid=$!

}

# Used in debugging to give feedback via standard out
function debug_message()
{
	#set +x
	if [ "$verboseMode" = 1 ]; then
		/bin/echo "PS: DEBUG: $*"
	fi
	#set -x
}

function timenow {
	/bin/date "+%Y%m%dT%H%M%S%z"
}

# Globally check currentUser
# currentuser=$(stat -f '%Su' /dev/console)
# Get the currently logged in user (recommended by Mac community)
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
scriptName=$(/usr/bin/basename "$0")
currentDir="$(/bin/pwd)"

function check_report()
{

	/bin/echo "PS: Running PanSift: $scriptName - $scriptVersion"
	/bin/echo "PS: Date/time: $(timenow)"
	/bin/echo "PS: Current Directory: $currentDir"

	if [[ -z $currentUser || $currentUser == "root" || $currentUser == "loginwindow" ]]; then
		/bin/echo "PS: Continuing with no active user logged in."
		if [[ -d /Applications/Pansift.app ]]; then
			/bin/echo "PS: Found an existing Pansift.app in Applications but no logged in user."
		else
			/bin/echo "PS: No existing PanSift install found, please use an unattended installer for a logged in user."
			cleanup_and_exit 1 "PS: Exiting with error as no existing install found."
		fi
	else
		echo "PS: Continuing and note user: $currentUser is logged in and available."
		userHomeFolder=$(dscl . -read /users/${currentUser} NFSHomeDirectory | cut -d " " -f 2)
		if [[ -s "$userHomeFolder/Library/Preferences/Pansift/pansift_uuid.conf" && -s "$userHomeFolder/Library/Preferences/Pansift/pansift_ingest.conf" && -s "$userHomeFolder/Library/Preferences/Pansift/pansift_token.conf" ]]; then
			/bin/echo "PS: Found Pansift preferences files for bucket UUID, ingest URL, and write/ZTP token, continuing..."
			pansift_uuid=$(head -n1 "$userHomeFolder"/Library/Preferences/Pansift/pansift_uuid.conf)
			pansift_ingest=$(head -n1 "$userHomeFolder"/Library/Preferences/Pansift/pansift_ingest.conf)
			pansift_token=$(head -n1 "$userHomeFolder"/Library/Preferences/Pansift/pansift_token.conf)
			/bin/echo "PS: Bucket UUID: $pansift_uuid"
			/bin/echo "PS: Ingest URL: $pansift_ingest"
			/bin/echo "PS: Write/ZTP Token: $pansift_token"
		else
			/bin/echo "PS: No existing PanSift bucket UUID, ingest URL, or token found in: $userHomeFolder/Library/Preferences/"
			/bin/echo "PS: Please use an unattended installer with a logged in user to preposition settings."
			cleanup_and_exit 1 "PS: Exiting with an error as no Pansift settings or tokens found for: $currentUser in: $userHomeFolder/Library/Preferences/"
		fi
		echo "PS: Contents of $userHomeFolder/Library/Preferences/Pansift"
		ls -al "$userHomeFolder"/Library/Preferences/Pansift

		echo "PS: Contents of $userHomeFolder/Library/Application\ Scripts/Pansift"
		ls -alR "$userHomeFolder"/Library/Application\ Scripts/Pansift

		echo "PS: Contents of $userHomeFolder/Library/Application\ Support/Pansift"
		ls -alR "$userHomeFolder"/Library/Application\ Support/Pansift

		echo "PS: Contents of $userHomeFolder/Library/Logs/Pansift"
		ls -alR "$userHomeFolder"/Library/Logs/Pansift
	fi
}

##########################
# Script Starts Here  #
##########################

#Trap will hopefully run our exit function even if the script is cancelled or interrupted
trap cleanup_and_exit 1 2 3 6

# 1) SIGHUP 2) SIGINT 3) SIGQUIT 6) SIGABRT

#Make sure we're running with root privileges
verify_root_user

# Don't let the computer sleep until we're done
no_sleeping

#Print the preinstall Summary
check_report

#If we still haven't exited, that means there have been no failures detected. Cleanup and exit
cleanup_and_exit 0 "PS: Check report successful."
