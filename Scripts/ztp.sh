#!/usr/bin/env bash

# Note: Should we really expose stagingapp.pansift.com ? It's on the Internets anyway?
# Require an target environment switch and UUID argument or just exit.

usage() { echo -e "Usage: [-t] [-s] [-p] <uuid>\nWhere '-t' is test, '-s' staging, and '-p' for production" 1>&2; exit 0; }

while getopts "t:s:p:" o; do
	case "${o}" in
		t)
			uuid=${OPTARG}
			url="https://localapp.pansift.com/ztp"
			;;
		s)
			uuid=${OPTARG}
			url="https://stagingapp.pansift.com/ztp"
			;;
		p)
			uuid=${OPTARG}
			#url="https://webrouter.pansift.com/hooks/ztp"
			url="https://app.pansift.com/ztp"
			;;
		*)
			#exit 1;
			usage
			;;
	esac
done
shift $((OPTIND-1))

if [ -z "${uuid}" ]; then
	#exit 1;
	usage
fi
# echo "uuid = ${uuid} and url = ${url}"

preferences="$HOME"/Library/Preferences/Pansift/pansift.conf
if test -f "$preferences"; then
	source "$preferences"
	pansift_ingest_file="$PANSIFT_PREFERENCES"/pansift_ingest.conf
	pansift_token_file="$PANSIFT_PREFERENCES"/pansift_token.conf
fi

if [[ $uuid =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
	#uuid=$(echo -n "$1" | tr '[:upper:]' '[:lower:]')
	user_agent="pansift-"$uuid
	curl_response=$(curl -A "$user_agent" -k -s --data "uuid=$uuid" $url)
	token=$(echo -n "$curl_response" | cut -d',' -f2 | tr -d '\r')
	ingest=$(echo -n "$curl_response" | cut -d',' -f3 | tr -d '\r')
	if [[ $token =~ ^[-_A-Z0-9a-z]{86}==$ ]]; then 
		echo -n "$token" > $pansift_token_file 
		ingest_regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
		if [[ $ingest =~ $ingest_regex ]]; then
			echo -n "$ingest" > $pansift_ingest_file
			echo -n "${token},${ingest}"
		else
			echo "null,null,ingest_url_problem"
			exit 1
		fi    
	else
		echo "null,null,token_format_problem"
		exit 1
	fi
else
	echo "null,null,arg_format_problem"
	exit 1
fi
