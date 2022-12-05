#!/usr/bin/env bash

# To be run in Mosyle "Custom Command" with - "Enable Variables for this profile"
# and also - "Execution Settings" of 
# -- "Every user sign-in" and 
# -- "Only once (Event Required)"

# set -e
# set -x

scriptName=$(basename "$0")
currentDir="$(pwd)"

function timenow {
  date "+%Y%m%dT%H%M%S%z"
}

echo "Running PanSift Test: $scriptName at $(timenow) with..."
echo "Current Directory: $currentDir"
echo "Current USER running script is: $USER"
echo "Current HOME is: $HOME"
echo "Last console user was: %LastConsoleUser%" # This is a Mosyle specific smart variable replacement 
echo "We will switch to console user irrespective."

# Get the currently logged in user (recommended by Mac community)
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
echo "Console USER is: $currentUser"

# Current User home folder (recommended by Mac community)
userHomeFolder=$(dscl . -read /users/${currentUser} NFSHomeDirectory | cut -d " " -f 2)
echo "$currentUser HOME folder is: $userHomeFolder"

echo "Ensuring we run as the logged in user..."

sudo -H -u $currentUser userHomeFolder="$userHomeFolder" /bin/bash <<'END'
echo "userHomeFolder: $userHomeFolder and HOME: $HOME"
echo "Contents of $userHomeFolder/Library/Preferences/Pansift"
ls -al "$userHomeFolder"/Library/Preferences/Pansift

echo "Contents of $userHomeFolder/Library/Application\ Scripts/Pansift"
ls -alR "$userHomeFolder"/Library/Application\ Scripts/Pansift

echo "Contents of $userHomeFolder/Library/Application\ Support/Pansift"
ls -alR "$userHomeFolder"/Library/Application\ Support/Pansift

echo "Contents of $userHomeFolder/Library/Logs/Pansift"
ls -alR "$userHomeFolder"/Library/Logs/Pansift
END
