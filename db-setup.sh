#!/usr/bin/env bash

url="http://aeuw1-p3t0002.infra.p3.pansift.com:9000/hooks/setup"
token=$(curl -s --data "uuid=$1" $url | cut -d',' -f3 | tr -d '\r')
[[ "${#token}" -eq 88 ]] && export pansift_token=$token && echo "$token" || echo "null"
