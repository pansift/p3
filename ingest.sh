#!/usr/bin/env bash

# Require an UUID argument or just return localhost

# This requires connectivity, what about when no connectivity and there's a restart?

if [[ $1 =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
  url="https://webrouter.pansift.com/hooks/ingestrouter"
  ingest=$(curl -s --data "uuid=$1" $url | tr -d '\r')
  regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
  if [[ $ingest =~ $regex ]]
  then 
    echo $ingest
  else
    exit 0
  fi
else
  exit 0
fi
