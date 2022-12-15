#!/usr/bin/env bash

# set -x
# verboseMode=1

# Forked from https://github.com/SecondSonConsulting/macOS-Scripts/blob/main/installGenericPKG.sh
# Thanks to: Trevor Sysock (aka @bigmacadmin) at Second Son Consulting Inc.

scriptVersion="v2.2"

# Important: This is not an install script for Mosyle but an updater *only* for PanSift so 
# there must be an existing install or it will exit.

if [[ -d /Applications/Pansift.app ]]; then
	echo "PS: Found an existing PanSift install so will continue..."
else
	echo "PS: No existing PanSift install found, please use an unattended installer for a logged in user."
	echo "PS: Exiting as an error."
	exit 1
fi

scriptName=$(basename "$0")
currentDir="$(pwd)"

function timenow {
  date "+%Y%m%dT%H%M%S%z"
}

echo "PS: Running PanSift: $scriptName at $(timenow) with..."
echo "PS: Current Directory: $currentDir"

# currentuser=$(stat -f '%Su' /dev/console)
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
if [[ -z $currentUser || $currentUser == "root" || $currentUser == "loginwindow" ]]; then
  echo "Not going to open Pansift.app as no user logged in... is this an update only?"
else
  echo "Opening Pansift.app (PS) as user: $currentUser"
  sudo -H -u $currentUser open /Applications/Pansift.app
fi



# Usage:
# Can be run as a Mosyle Custom Command or locally.
# Any step in the script that fails will produce an easily read error report to standard output.
# Uncomment set -x and/or verboseMode=1 at the top of the script for advanced debugging

# Arguments can be defined here in the script, or passed at the command line. 
# If passed at the command line, arguments MUST BE IN THE FOLLOWING ORDER:
# ./installGenericPKG.sh [pathtopackage] [md5 | TeamID]

# TeamID and MD5 are *not* required fields, but are strongly recommended to ensure you install 
# what you think you are installing.

# PKGs can be validated prior to install by either the TeamID or an MD5 hash.
# If both TeamID and MD5 are defined in the script, both will be checked.
# When running from the command line, md5 and TeamID can be passed as either argument 2 or 3 or both
# 
# Example: Download a PKG at https://test.example.host.tld/Remote.pkg and verify by TeamID
# ./installGenericPKG.sh https://test.example.host.tld/Remote.pkg 7Q6XP5698G
#
# Example: Run a PKG from the local disk and verify by TeamID and MD5
# ./installGenericPKG.sh /path/to/installer.pkg 7Q6XP5698G 9741c346eeasdf31163e13b9db1241b3
#


######################################
#
# User Configuration
#
######################################

#This is low consequence, and only used for the temp directory. Make it something meaningful to you. No special characters.
#This can typically be left as default: nameOfInstall="InstallPKG"
nameOfInstall="pansift_updater_pkg"

#Where is the PKG located? Update this for your PanSift account or the version you want.
pathToPKG="https://github.com/pansift/p3/raw/main/Pansift-6d0280d1-3eed-4246-8684-80efb2370eab.pkg"

#TeamID value is optional, but recommended. If not in use, this should read: expectedTeamID=""
expectedTeamID=""

#MD5 value is optional, but recommended. If not in use, this should read: expectedMD5=""
expectedMD5=""

######################################
#
# Do not modify below for normal use 
#
######################################


#################
#	Functions	#
#################

function verify_root_user()
{
	# check we are running as root
	if [[ $(id -u) -ne 0 ]]; then
	echo "PS: ERROR: This script must be run as root **EXITING**"
	exit 1
	fi

}

function rm_if_exists()
{
    #Only rm something if the variable has a value and the thing exists!
    if [ -n "${1}" ] && [ -e "${1}" ];then
        rm -r "${1}"
    fi
}

#This function exits the script, deleting the temp files. first argument is the exit code, second argument is the message reported.
#example: cleanup_and_exit 1 "Download Failed."
function cleanup_and_exit()
{
	echo "${2}"
	rm_if_exists "$tmpDir"
	kill "$caffeinatepid" > /dev/null 2>&1
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

# This is a report regarding the installation details that gets printed prior to the script actually running
function preinstall_summary_report()
{
	echo "$scriptName - $scriptVersion"
	echo "PS: Date/time: $(timenow)"
	echo "PS: Location: $pathToPKG"
	echo "PS: Location Type: $pkgLocationType"
	echo "PS: Expected MD5 is: $expectedMD5"
	echo "PS: Expected TeamID is: $expectedTeamID"
	#If there is no TeamID and no MD5 verification configured print a warning
	if [ -z "$expectedTeamID" ] && [ -z "$expectedMD5" ]; then
		echo "PS: WARNING: No verification of the PKG before it is installed. Provide an MD5 or TeamID for better security and stability.**"
	fi
}

#This function will download the pkg (if it is hosted via url) and then verify the MD5 or TeamID if provided.
function download_pkg()
{
	# First, check if we have to download the PKG
	if [ "$pkgLocationType" = "url" ]; then
		pkgInstallerPath="$tmpDir"/"$nameOfInstall".pkg
		#Download installer to tmp folder
		curl -LJs "$pathToPKG" -o "$pkgInstallerPath"
		downloadResult=$?
		#Verify curl exited with 0
		if [ "$downloadResult" != 0 ]; then
			cleanup_and_exit 1 "PS: Download failed. Exiting."
		fi
		debug_message "PS: PKG downloaded successfully."
	else
		#If the PKG is a local file, set our installer path variable accordingly
		pkgInstallerPath="$pathToPKG"
	fi
}

function verify_pkg()
{
	# If an expectedMD5 was given, test against the actual installer and exit upon mismatch
	actualMD5="$(md5 -q "$pkgInstallerPath")"
	if [ -n "$expectedMD5" ] && [ "$actualMD5" != "$expectedMD5" ]; then
	cleanup_and_exit 1 "PS: ERROR - MD5 mismatch. Exiting."
	fi

	# If an expectedTeamID was given, test against the actual installer and exit upon mismatch
	actualTeamID=$(spctl -a -vv -t install "$pkgInstallerPath" 2>&1 | awk -F '(' '/origin=/ {print $2 }' | tr -d ')' )
	# If an TeamID was given, test against the actual installer and exit upon mismatch
	if [ -n "$expectedTeamID" ] && [ "$actualTeamID" != "$expectedTeamID" ]; then
		cleanup_and_exit 1 "PS: ERROR - TeamID mismatch. Exiting."
	fi

	#Lets take an opportunity to just verify that the PKG we're installing actually exists
	if [ ! -e "$pkgInstallerPath" ]; then
		cleanup_and_exit 1 "PS: ERROR - PKG does not exist at this location: $pkgInstallerPath"
	fi

}

function install_pkg()
{
	#Run the pkg and capture output to variable in case of error
	installExitMessage=$( { installer -allowUntrusted -pkg "$pkgInstallerPath" -target / > "$tmpDir"/fail.txt; } 2>&1 )
	installResult=$?

	#Verify install exited with 0
	if [ "$installResult" != 0 ]; then
			cleanup_and_exit 1 "PS: Installation command failed: $installExitMessage"
	fi

}

#################################
#	Validate and Process Input	#
#################################

# $1 - The first argument is the path to the PKG (either url or filepath). If no argument, fall back to script configuration.
if [ "$1" = "" ]; then
	debug_message "PS: No PKG defined in command-line arguments, defaulting to script configuration"
else
	pathToPKG="${1}"
fi

# Look at the given path to PKG, and determine if its a local file path or a URL.
if [[ ${pathToPKG:0:4} == "http" ]]; then
	# The path to the PKG appears to be a URL.
	pkgLocationType="url"
elif [ -e "$pathToPKG" ]; then
	# The path to the PKG appears to exist on the local file system
	pkgLocationType="filepath"
else
	#Some kind of invalid input, not starting with a / or with http. Exit with an error
	cleanup_and_exit 1 "PS: Path to PKG passed at command line appears to be invalid or undefined."
fi

# $2 - The second argument is either an MD5 or a TeamID.
if [ "${2}" = "" ]; then
	debug_message "PS: No Verification Value defined in command-line arguments, defaulting to script configuration"
elif [ ${#2} = 10 ]; then
	#The second argument is 10 characters, which indicates a TeamID.
	expectedTeamID="${2}"
elif [ ${#2} = 32 ]; then
	#The second argument is 10 characters, which indicates an MD5 hash
	expectedMD5="${2}"
else
	#There appears to be something wrong with the validation input, exit with an error
	cleanup_and_exit 1 "PS: TeamID or MD5 passed at command line appear to be invalid. Expecting 10 characters for TeamID or 32 for MD5."
fi

# $3 - The third argument is either an MD5 or a TeamID.
if [ "${3}" = "" ]; then
	debug_message "PS: Argument 3 is empty. Defaulting to script configuration"
elif [ ${#3} = 10 ]; then
	#The second argument is 10 characters, which indicates a TeamID.
	expectedTeamID="${3}"
elif [ ${#3} = 32 ]; then
	#The second argument is 10 characters, which indicates an MD5 hash
	expectedMD5="${3}"
else
	#There appears to be something wrong with the validation input, exit with an error
	cleanup_and_exit 1 "PS: TeamID or MD5 passed at command line appear to be invalid. Expecting 10 characters for TeamID or 32 for MD5."
fi

##########################
# Script Starts Here	#
##########################

#Trap will hopefully run our exit function even if the script is cancelled or interrupted
trap cleanup_and_exit 1 2 3 6

#Make sure we're running with root privileges
verify_root_user

#Create a temporary working directory
tmpDir=$(mktemp -d /var/tmp/"$nameOfInstall".XXXXXX)

# Don't let the computer sleep until we're done
no_sleeping

#Print the preinstall Summary
preinstall_summary_report

#Download happens here, if needed
download_pkg

#MD5 and TeamID verification happens here
verify_pkg

#If we haven't exited yet, then the PKG was verified and we can install
install_pkg

#If we still haven't exited, that means there have been no failures detected. Cleanup and exit
cleanup_and_exit 0 "PS: Installation reports successful"
