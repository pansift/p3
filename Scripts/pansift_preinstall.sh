#!/usr/bin/env bash

# THIS SCRIPT MUST BE RUN IN THE CONTEXT OF THE LOGGED IN USER AND NOT A SYSTEM OR HEADLESS ACCOUNT

# set -e
# set -vx
script_name=$(basename "$0")

CURRENTDIR="$(pwd)"

function timenow {
	date "+%Y%m%dT%H%M%S%z"
}
echo "Running PanSift: $script_name at $(timenow) with..."
echo "Directory: $CURRENTDIR"

echo "Shutting down any existing Pansift.app instances and related telegraf"
# Shut down the current Pansift.app if there is one
if [[ $(pgrep -f Pansift.app) ]]; then
  pkill -9 -f Pansift.app
fi
if [[ $(pgrep -f Pansift/telegraf-osx.conf) ]]; then
  pkill -9 -f Pansift/telegraf-osx.conf
fi

exit
