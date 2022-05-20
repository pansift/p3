#!/usr/bin/env bash

#set -e
#set -vx

# Moving things to the right places :)
# Being super verbose and as careful as can be with "rm"

preferences="$HOME"/Library/Preferences/Pansift/pansift.conf
if test -f "$preferences"; then
	source "$preferences"
fi

if [[ -d "$PANSIFT_PREFERENCES" ]]; then
	pansift_uuid_file="$PANSIFT_PREFERENCES"/pansift_uuid.conf
	if test -f "$pansift_uuid_file"; then
		rm $pansift_uuid_file
	fi
	pansift_ingest_file="$PANSIFT_PREFERENCES"/pansift_ingest.conf
	if test -f "$pansift_ingest_file"; then
		rm $pansift_ingest_file
	fi
	pansift_token_file="$PANSIFT_PREFERENCES"/pansift_token.conf
	if test -f "$pansift_token_file"; then
		rm $pansift_token_file
	fi
fi

cd "$PANSIFT_SCRIPTS" && ./pansift -b
exit
