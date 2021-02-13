#!/usr/bin/env bash

# Note: GitHub serves "raw" pages with Cache-Control: max-age=300. That's specified in seconds, meaning the pages are intended to be cached for 5 minutes. You can see this if you open the Developer Tools in your web browser of choice before clicking the "Raw" button on GitHub.

curl -s https://raw.githubusercontent.com/pansift/p3/main/osx_network_default_script.sh > $HOME/p3/osx_network_default_script.sh
