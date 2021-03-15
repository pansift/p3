#!/usr/bin/env bash

#set -e
#set -vx

# Moving things to the right places :)
# Fresh start just in case! Will get updated...
defaults delete com.matryer.BitBar # This can't coexist etc.
defaults delete com.pansift.p3bar
defaults delete /Library/Preferences/com.matryer.BitBar # Nor this...
defaults delete /Library/Preferences/com.pansift.p3bar

# Speed ingest but could be dangerous if you don't look
source ./Preferences/pansift.conf

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
  rsync -a ./Scripts/* "$PANSIFT_SCRIPTS"
  # conf to ~/Library/Preferences/Pansift
  rsync -a ./Preferences/*.conf "$PANSIFT_PREFERENCES"
  rsync -a ./Preferences/*.plist "$PANSIFT_PREFERENCES"
  # app to /Applications
  rsync -a ./Pansift.app /Applications
  # Telegraf Support
  rsync -a ./Support/telegraf "$PANSIFT_SUPPORT"
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

#cp "$HOME"/Library/Preferences/Pansift/org.pansift.agent.plist ~/Library/LaunchAgents/org.pansift.agent.plist
#launchctl unload "$HOME"/Library/LaunchAgents/org.pansift.agent.plist && launchctl load -w "$HOME"/Library/LaunchAgents/org.pansift.agent.plist

cd "$PANSIFT_SCRIPTS" && ./pansift -t && open /Applications/Pansift.app
