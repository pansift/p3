#!/usr/bin/env bash

#  bootstrap.sh
#  Pansift 2021
#
#  Created by laptop on 15/03/2021.
#  Copyright © 2021 Pansift. All rights reserved.

#set -e
#set -vx

# Note: We are passing in the app bundle path via $1 so it works
# irrespective of the drag/install location on dev or prod
# This is triggered on run by the application

# Get Basic script settings
source "$1"/Contents/Resources/Preferences/pansift.conf

# Set App defaults that relate to userland / BUT RUNNING TOO LATE
#defaults write com.pansift.p3bar pluginsDirectory "$PANSIFT_SCRIPTS"/Plugins
#defaults write com.pansift.p3bar NSNavLastRootDirectory "$PANSIFT_SCRIPTS"/Plugins
#defaults write com.pansift.p3bar userConfigDisabled -bool true

# Configuration and preferences files
mkdir -p "$PANSIFT_PREFERENCES"

# Scripts and additional executables
mkdir -p "$PANSIFT_SCRIPTS"
mkdir -p "$PANSIFT_SCRIPTS"/Plugins

# Logs, logs, logs
mkdir -p "$PANSIFT_LOGS"

# PIDs and other flotsam
mkdir -p "$PANSIFT_SUPPORT"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "Not supported on Linux yet"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # Mac OSX
  # Main scripts and settings need to get moved...
  # scripts to ~/Library/Pansift
  rsync -aru "$1"/Contents/Resources/Scripts/* "$PANSIFT_SCRIPTS"
  # conf to ~/Library/Preferences/Pansift
  rsync -aru "$1"/Contents/Resources/Preferences/*.conf "$PANSIFT_PREFERENCES"
  # Telegraf Support
  rsync -aru "$1"/Contents/Resources/Support/telegraf "$PANSIFT_SUPPORT"
elif [[ "$OSTYPE" == "cygwin" ]]; then
  # POSIX compatibility layer and Linux environment emulation for Windows
  echo "Not supported on Cygwin yet"
elif [[ "$OSTYPE" == "msys" ]]; then
  # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
  echo "Not supported on MinGW yet."
elif [[ "$OSTYPE" == "win32" ]]; then
  # I'm not sure this can happen.
  echo "Not supported on Windows yet"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
  echo "Not supported on FreeBSD yet."
  # ...
else
  echo "Not supported on this platform yet"
fi

if [[ $(pgrep -f Pansift/telegraf-osx.conf) ]]; then
	pkill -9 -f Pansift/telegraf-osx.conf;
fi
cd "$PANSIFT_SCRIPTS" && ./pansift -b &
disown -a
#message="You can access PanSift via the 'PS' in the menubar (top of screen) and don't forget to claim your agent."
#applescriptCode="display dialog \"$message\" buttons {\"OK\"} default button \"OK\" with title \"PanSift Installer\""
#show=$(osascript -e "$applescriptCode");
exit
