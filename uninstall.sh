#!/usr/bin/env bash

#set -e
#set -vx

# Moving things to the right places :)
# Being super verbose and as careful as can be with "rm"

source "$HOME"/Library/Preferences/Pansift/pansift.conf

#launchctl unload ~/Library/LaunchAgents/org.pansift.agent.plist
defaults delete com.matryer.BitBar

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "Not supported on Linux yet" 
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # Mac OSX
  # Scripts to Trash
  if [[ -d "$PANSIFT_SCRIPTS" ]]; then
    cp -R "$PANSIFT_SCRIPTS" "$HOME"/.Trash
    cd "$PANSIFT_SCRIPTS" && rm -rf ../Pansift/*
    cd .. && rmdir ./Pansift
    cd "$HOME"
  fi
  # Conf files
  if [[ -d "$PANSIFT_PREFERENCES" ]]; then
    if [[ -f "$PANSIFT_PREFERENCES"/pansift_token.conf ]]; then
      rm "$PANSIFT_PREFERENCES"/pansift_token.conf 
    fi
    cp -R "$PANSIFT_PREFERENCES" "$HOME"/.Trash
    cd "$PANSIFT_PREFERENCES" && rm -rf ../Pansift/*
    cd .. && rmdir ./Pansift
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
    cd "$PANSIFT_LOGS" && rm -rf ../Pansift/*
    cd .. && rmdir ./Pansift
    cd "$HOME"
  fi
  # Telegraf Support
  if [[ -d "$PANSIFT_SUPPORT" ]]; then
    cp -R "$PANSIFT_SUPPORT" "$HOME"/.Trash
    cd "$PANSIFT_SUPPORT" && rm -rf ../Pansift/*
    cd .. && rmdir ./Pansift
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

pkill -9 telegraf

echo "=========================================================="
echo "Now please empty your Trash at your discretion"
echo "And log in to https://pansift.com to request data deletion"
echo "Note: Only account admins can request deletions!"
echo "=========================================================="
