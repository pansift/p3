#!/usr/bin/env bash

pansift_uuid_file=$PANSIFT_PREFERENCES/pansift_uuid.conf
if test -f "$pansift_uuid_file"; then
  line=$(head -n 1 "$pansift_uuid_file")
  pansift_uuid=$(echo -n "$line" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r')
fi

open https://app.pansift.com?uuid=${pansift_uuid}
