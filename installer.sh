#!/usr/bin/env bash

#set -e
#set -vx

# Moving things to the right places :)

defaults delete com.matryer.BitBar
defaults delete /Library/Preferences/com.matryer.BitBar

# Configuration and preferences files
PANSIFT_PREFERENCES="$HOME"/Library/Preferences/Pansift
mkdir -p "$PANSIFT_PREFERENCES"
export PANSIFT_PREFERENCES="$PANSIFT_PREFERENCES"

# Scripts and additional executables
PANSIFT_SCRIPTS="$HOME"/Library/Application\ Scripts/Pansift
mkdir -p "$PANSIFT_SCRIPTS"
mkdir -p "$PANSIFT_SCRIPTS"/Plugins
export PANSIFT_SCRIPTS="$PANSIFT_SCRIPTS"

# Logs, logs, logs
PANSIFT_LOGS="$HOME"/Library/Logs/Pansift
mkdir -p "$PANSIFT_LOGS"
export PANSIFT_LOGS="$PANSIFT_LOGS"

# PIDs and other flotsam
PANSIFT_SUPPORT="$HOME"/Library/Application\ Support/Pansift
mkdir -p "$PANSIFT_SUPPORT"
export PANSIFT_SUPPORT="$PANSIFT_SUPPORT"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "Not supported on Linux yet" 
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # Mac OSX
  # scripts to ~/Library/Pansift
  cp -Rf ./Scripts/* "$PANSIFT_SCRIPTS"
  #cp -Rf ./Scripts/Plugins/* "$PANSIFT_SCRIPTS"/Plugins
  # conf to ~/Library/Preferences/Pansift
  cp -Rf ./Preferences/*.conf "$PANSIFT_PREFERENCES"
  # app to /Applications
  cp -Rf ./Pansift.app /Applications
  # Telegraf Support
  cp -Rf ./Support/telegraf "$PANSIFT_SUPPORT"
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

cd "$PANSIFT_SCRIPTS" && ./pansift && open /Applications/Pansift.app
