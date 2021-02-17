#!/usr/bin/env bash

url="http://webrouter.infra.p3.pansift.com:443/hooks/ingestrouter"
ingest=$(curl -s --data "uuid=$1" $url | tr -d '\r')
regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
if [[ $ingest =~ $regex ]]
then 
    echo $ingest
else
    echo $pansift_default_ingest
fi
