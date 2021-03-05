#!/usr/bin/env bash

# Require an UUID argument or just exit.

if [[ $1 =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
  url="https://webrouter.pansift.com/hooks/ztp"
  uuid=$(echo -n "$1" | tr '[:upper:]' '[:lower:]')
  user_agent="pansift-"$uuid
  curl_response=$(curl -A "$user_agent" -k -s --data "uuid=$uuid" $url)
  token=$(echo -n "$curl_response" | cut -d',' -f2 | tr -d '\r')
  ingest=$(echo -n "$curl_response" | cut -d',' -f3 | tr -d '\r')
  if [[ $token =~ ^[-_A-Z0-9a-z]{86}==$ ]]; then 
    ingest_regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
    if [[ $ingest =~ $ingest_regex ]]; then
      echo -n "${token},${ingest}"
    else
      echo "null,null,ingest_url_problem"
      exit 0
    fi    
  else
    echo "null,null,token_format_problem"
  fi
else
  echo "null,null,arg_format_problem"
  exit 0
fi
