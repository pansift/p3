#!/usr/bin/env bash

#set -e
#set -vx

# Moving things to the right places :)

source ./Preferences/pansift.conf

#launchctl unload ~/Library/LaunchAgents/org.pansift.agent.plist
defaults delete com.matryer.BitBar

# Configuration and preferences files
#PANSIFT_PREFERENCES="$HOME"/Library/Preferences/Pansift

# Scripts and additional executables
#PANSIFT_SCRIPTS="$HOME"/Library/Application\ Scripts/Pansift

# Logs, logs, logs
#PANSIFT_LOGS="$HOME"/Library/Logs/Pansift

# PIDs and other flotsam
#PANSIFT_SUPPORT="$HOME"/Library/Application\ Support/Pansift

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "Not supported on Linux yet" 
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # Mac OSX
  # Scripts to Trash
  if [[ -d "$PANSIFT_SCRIPTS" ]]; then
    cp -R "$PANSIFT_SCRIPTS" "$HOME"/.Trash
    cd "$PANSIFT_SCRIPTS" && rm -rf ../Pansift
    cd "$HOME"
  fi
  # Conf files
  if [[ -d "$PANSIFT_PREFERENCES" ]]; then
    if [[ -f "$PANSIFT_PREFERENCES"/pansift_token.conf ]]; then
      rm "$PANSIFT_PREFERENCES"/pansift_token.conf 
    fi
    cp -R "$PANSIFT_PREFERENCES" "$HOME"/.Trash
    cd "$PANSIFT_PREFRENCES" && rm -rf ../Pansift
    cd "$HOME"
  fi
  # /Applications
    if [[ -f "/Applications/Pansift.app" ]]; then
  cp -R /Applications/Pansift.app "$HOME"/.Trash
  cd /Applications && rm -rf Pansift.app
  fi
  # Logs
  if [[ -d "$PANSIFT_LOGS" ]]; then
    cp -R "$PANSIFT_LOGS" "$HOME"/.Trash
    cd "$PANSIFT_LOGS" && rm -rf ../Pansift
    cd "$HOME"
  fi
  # Telegraf Support
  if [[ -d "$PANSIFT_SUPPORT" ]]; then
    cp -R "$PANSIFT_SUPPORT" "$HOME"/.Trash
    cd "$PANSIFT_SUPPORT" && rm -rf ../Pansift 
    cd "$HOME"
  fi
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

pkill telegraf

echo "===================================="
echo "Now please empty your Trash at your discretion"
echo "===================================="
