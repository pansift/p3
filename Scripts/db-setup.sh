#!/usr/bin/env bash

# Require an UUID argument or just exit.

if [[ $1 =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
  url="https://webrouter.pansift.com/hooks/setup"
  uuid=$(echo -n "$1" | tr '[:upper:]' '[:lower:]')
  token=$(curl -k -s --data "uuid=$uuid" $url | cut -d',' -f2 | tr -d '\r')
  if [[ $token =~ ^[-_A-Z0-9a-z]{86}==$ ]]; then 
    echo -n "$token"
  else
    echo "null"
  fi
else
  exit 0
fi
