#/usr/bin/env bash

# Pansift Telegraf input.exec script for writing influx measurements and tags

#set -e
#set -vx

# Note: We can't afford to have a comma or space out of place with InfluxDB ingestion in the line protocol
LDIFS=$IFS

script_name=$(basename "$0")
# Get configuration targets etc
source ~/p3/pansift.conf

if [[ ${#1} = 0 ]]; then
  echo "Usage: Pass one parameter -n|--network -m|--machine"
  echo "Usage: ./$script_name -i"
  exit 0;
fi

airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
curl_path="/opt/local/bin/curl"
curl_user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.146 Safari/537.36"
dns_query_host=$(uuidgen)
dns_query_domain="doesnotexist.pansift.com"
dns_query="$dns_query_host.$dns_query_domain"
systemsoftware=$(sw_vers)
osx_mainline=$(echo -n "$systemsoftware" | grep -i "productversion" | cut -d':' -f2- | cut -d'.' -f1 | xargs)

# Old versions of curl will fail with status 53 on SSL/TLS negotiation on newer hosts
# User really needs a newer curl binary but can also put defaults here
if test -f "$curl_path"; then
  curl_binary="/opt/local/bin/curl --no-keepalive"
else
  curl_binary="/usr/bin/curl --no-keepalive"
fi

remove_chars () {
  read data
  newdata=$(echo -n "$data" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r' | sed 's! !\\ !g')
  echo -n $newdata
}

remove_chars_except_spaces () {
  # This is for fieldset fields where there may be a space, as telegraf will add it's own backslash \ and if we already have one then we get "\\ "
  read data
  newdata=$(echo -n "$data" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r')
  echo -n $newdata
}

system_measure () {
  #hostname=$(hostname | remove_chars)
  #username=$(echo -n "$USER" | remove_chars)
  # Uptime and uptime_format are already covered by the default plugin.
  #uptime=$(sysctl kern.boottime | cut -d' ' -f5 | cut -d',' -f1)

  product_name=$(echo -n "$systemsoftware" | egrep -i "productname" | cut -d':' -f2- | remove_chars)
  product_version=$(echo -n "$systemsoftware" | egrep -i "productversion" | cut -d':' -f2- | remove_chars)
  build_version=$(echo -n "$systemsoftware" | egrep -i "buildversion" | cut -d':' -f2- | remove_chars)

  systemprofile_sphardwaredatatype=$(system_profiler SPHardwareDataType)
  model_name=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "model name" | cut -d':' -f2- | remove_chars)
  model_identifier=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "model identifier" | cut -d':' -f2- | remove_chars)
  memory=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "memory" | cut -d':' -f2- | remove_chars_except_spaces)
  boot_romversion=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "boot rom version" | cut -d':' -f2- | remove_chars)
  smc_version=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "smc version" | cut -d':' -f2- | remove_chars)
  serial_number=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "serial number" | cut -d':' -f2- | remove_chars)
}


network_measure () {
  if [ $osx_mainline == 11 ]; then
    netstat4_print_position=4 # 11.x Big Sur onwards
  else 
    netstat4_print_position=6 # 10.x 
  fi
  netstat4=$(netstat -rn -f inet)
  netstat6=$(netstat -rn -f inet6)
  dg4_ip=$(echo -n "$netstat4" | grep -qi default || { echo -n 'none'; exit 0;}; echo -n "$netstat4" | grep -i default | awk '{print $2}' | remove_chars)
  dg6_fullgw=$(echo -n "$netstat6" | grep -qi default || { echo -n 'none'; exit 0;}; echo -n "$netstat6" | grep -i default | awk '{print $2}' | remove_chars)
  dg6_ip=$(echo -n "$netstat6" | grep -qi default || { echo -n 'none'; exit 0;}; echo -n "$netstat6" | grep -i default | awk '{print $2}' | cut -d'%' -f1 | remove_chars)
  dg4_interface=$(echo -n "$netstat4" | grep -qi default || { echo -n 'none'; exit 0;}; echo -n "$netstat4" | grep -i default | awk -v x=$netstat4_print_position '{print $x}' | remove_chars)
  dg6_interface=$(echo -n "$netstat6" | grep -qi default || { echo -n 'none'; exit 0; }; echo -n "$netstat6" | grep -i default | awk '{print $2}'| remove_chars)
  if [ ! "$dg4_ip" == "none" ]; then
    dg4_router_ether=$(arp "$dg4_ip")
  else
    dg4_router_ether="none"
  fi
  if [ ! "$dg4_interface" == "none" ]; then
    dg4_interface_ether=$(ifconfig "$dg4_interface" | egrep ether | xargs | cut -d' ' -f2 | remove_chars)
  else
    dg4_interface_ether="none"
  fi
  if [ ! "$dg6_interface" == "none" ]; then
    dg6_interface_ether=$(ifconfig $(echo -n "$dg6_interface" | cut -d'%' -f2)  | egrep "ether" | xargs | cut -d' ' -f2 | remove_chars)
    dg6_router_ether=$(ndp -anr | egrep "$dg6_interface" | xargs | cut -d' ' -f2 | remove_chars )
  else
    dg6_interface_ether="none"
    dg6_router_ether="none"
  fi

  dg4_response=$(echo -n "$netstat4" | grep -qi default || { echo -n 0; exit 0; }; [[ ! "$dg4_ip" == "none" ]] && ping -c1 -i1 -o "$dg4_ip" | tail -n1 | cut -d' ' -f4 | cut -d'/' -f2 || echo -n 0)
  dg6_response=$(echo -n "$netstat6" | grep -qi default || { echo -n 0; exit 0; }; [[ ! "$dg6_ip" == "none" ]] && ping6 -c1 -i1 -o "$dg6_fullgw" | tail -n1 | cut -d' ' -f4 | cut -d'/' -f2 || echo -n 0)

  if [[ "$dg4_response" > 0 ]] || [[ "$dg6_respone" > 0 ]]; then
    locally_connected="true"
  else
    locally_connected="false"
  fi  
  dns4_query_response="0"
  dns6_query_response="0"
  RESOLV=/etc/resolv.conf
  if test -f "$RESOLV"; then
    dns4_primary=$(cat /etc/resolv.conf | grep -q '\..*\..*\.' || { echo -n '0.0.0.0'; exit 0; }; cat /etc/resolv.conf | grep '\..*\..*\.' | head -n1 | cut -d' ' -f2 | remove_chars)
    dns6_primary=$(cat /etc/resolv.conf | grep -q 'nameserver.*:' || { echo -n '::'; exit 0; }; cat /etc/resolv.conf | grep 'nameserver.*:' | head -n1 | cut -d' ' -f2 | remove_chars)
    if [ $dns4_primary != "0.0.0.0" ]; then
      dns4_query_response=$(dig -4 +tries=2 @"$dns4_primary" "$dns_query" | grep -m1 -i "query time" | cut -d' ' -f4 | remove_chars)
    else
      dns4_query_response="0"
    fi
    if [ $dns6_primary != "::" ]; then
      dns6_query_response=$(dig -6 +tries=2 @"$dns6_primary" "$dns_query" | grep -m1 -i "query time" | cut -d' ' -f4 | remove_chars)
      [ -z "$dns6_query_response" ] && dns6_query_response="0"
    else 
      dns6_query_response="0"
    fi
  else
    dns4_primary="0.0.0.0"
    dns6_primary="::"
  fi
}

internet_measure () {
  # We need basic ICMP response times from lighthouse too?
  #
  internet4_connected=$(ping -o -c3 -i1 -t5 $pansift_icmp4_target > /dev/null 2>&1 || { echo -n "false"; exit 0;}; echo -n "true")
  internet6_connected=$(ping6 -o -c3 -i1 $pansift_icmp6_target > /dev/null 2>&1 || { echo -n "false"; exit 0;}; echo -n "true")
  internet_connected="false" # Default to be overwritten below
  internet_dualstack="false" # "
  ipv4_only="false" # "
  ipv6_only="false" # "
  internet4_public_ip="0.0.0.0"
  internet6_public_ip="::"
  internet_asn="0i"

  if [ "$internet4_connected" == "true" ] || [ "$internet6_connected" == "true" ]; then
    internet_connected="true"
  else
    internet_connected="false"
    internet4_public_ip="0.0.0.0"
    internet6_public_ip="::"
    internet_asn="0i"
  fi
  if [ "$internet4_connected" == "true" ] && [ "$internet6_connected" == "true" ]; then
    ipv4_only="false"
    ipv6_only="false"
    internet_dualstack="true"
    lighthouse4=$($curl_binary -m3 -sN -4 -k -L -i "$pansift_lighthouse" 2>&1 || exit 0)
    lighthouse6=$($curl_binary -m3 -sN -6 -k -L -i "$pansift_lighthouse" 2>&1 || exit 0)
    internet_asn=$(echo -n "$lighthouse4" | grep -qi "x-pansift-client-asn" || { echo -n '0'; exit 0;}; echo -n "$lighthouse4" | grep -i "x-pansift-client-asn" | cut -d' ' -f2 | remove_chars )i
    internet4_public_ip=$(echo -n "$lighthouse4" | grep -qi "x-pansift-client-ip" || { echo -n '0.0.0.0'; exit 0;}; echo -n "$lighthouse4" | grep -i "x-pansift-client-ip" | cut -d' ' -f2 | remove_chars )
    internet6_public_ip=$(echo -n "$lighthouse6" | grep -qi "x-pansift-client-ip" || { echo -n '::'; exit 0;}; echo -n "$lighthouse6" | grep -i "x-pansift-client-ip" | cut -d' ' -f2 | remove_chars )
  fi
  if [ "$internet4_connected" == "true" ] && [ "$internet6_connected" == "false" ]; then
    ipv4_only="true"
    ipv6_only="false"
    internet_dualstack="false"
    lighthouse4=$($curl_binary -m3 -sN -4 -k -L -v "$pansift_lighthouse" --stderr - || exit 0)
    internet_asn=$(echo -n "$lighthouse4" | egrep -qi "x-pansift-client-asn" || { echo -n '0'; exit 0;}; echo -n "$lighthouse4" | egrep -i "x-pansift-client-asn" | cut -d' ' -f3 | remove_chars )i
    internet4_public_ip=$(echo -n "$lighthouse4" | egrep -qi "x-pansift-client-ip" || { echo -n '0.0.0.0'; exit 0;}; echo -n "$lighthouse4" | egrep -i "x-pansift-client-ip" | cut -d' ' -f3 | remove_chars )
    internet6_public_ip="::"
  fi
  if [ "$internet4_connected" == "false" ] && [ "$internet6_connected" == "true" ]; then
    ipv4_only="false"
    ipv6_only="true"
    internet_dualstack="false"
    lighthouse6=$($curl_binary -m3 -sN -6 -k -L -v "$pansift_lighthouse" --stderr - || exit 0)
    internet_asn=$(echo -n "$lighthouse6" | egrep -qi "x-pansift-client-asn" || { echo -n '0'; exit 0;}; echo -n "$lighthouse6" | egrep -i "x-pansift-client-asn" | cut -d' ' -f3 | remove_chars )i
    internet4_public_ip="0.0.0.0"
    internet6_public_ip=$(echo -n "$lighthouse6" | egrep -qi "x-pansift-client-ip" || { echo -n '::'; exit 0;}; echo -n "$lighthouse6" | egrep -i "x-pansift-client-ip" | cut -d' ' -f3 | remove_chars )
  fi
}

wlan_measure () {
  # This can probably be re-written with PlistBuddy for simplicity?
  airport_output=$($airport -I)
  wlan_connected=$(echo -n "$airport_output" | grep -q 'AirPort: Off' && echo -n 'false' || echo -n 'true')
  if [ $wlan_connected == "true" ]; then
    wlan_state=$(echo -n "$airport_output" | egrep -i '[[:space:]]state' | cut -d':' -f2- | remove_chars)
    wlan_opmode=$(echo -n "$airport_output"| egrep -i '[[:space:]]op mode' | cut -d':' -f2- | remove_chars)
    wlan_rssi=$(echo -n "$airport_output" | egrep -i '[[:space:]]agrCtlRSSI' | cut -d':' -f2- | remove_chars)
    wlan_noise=$(echo -n "$airport_output" | egrep -i '[[:space:]]agrCtlNoise' | cut -d':' -f2- | remove_chars)
    wlan_snr=$(var=$(( $(( $wlan_noise * -1)) - $(( $wlan_rssi * -1)) )); echo -n $var)i
    # because of mathematical operation, add back in i
    wlan_rssi="$wlan_rssi"i
    wlan_noise="$wlan_noise"i
    wlan_lasttxrate=$(echo -n "$airport_output"| egrep -i '[[:space:]]lastTxRate' | cut -d':' -f2- | remove_chars)i
    wlan_maxrate=$(echo -n "$airport_output" | egrep -i '[[:space:]]maxRate' | cut -d':' -f2- | remove_chars)i
    wlan_ssid=$(echo -n "$airport_output" | egrep -i '[[:space:]]ssid' | cut -d':' -f2- | awk '{$1=$1;print}')
    wlan_bssid=$(echo -n "$airport_output" | egrep -i '[[:space:]]bssid' | awk '{$1=$1;print}' | cut -d' ' -f2)
    wlan_mcs=$(echo -n "$airport_output"| egrep -i '[[:space:]]mcs' | cut -d':' -f2 | remove_chars)i
    wlan_80211auth=$(echo -n "$airport_output"| egrep -i '[[:space:]]802\.11 auth' |  cut -d':' -f2 | remove_chars)
    wlan_linkauth=$(echo -n "$airport_output" | egrep -i '[[:space:]]link auth' |  cut -d':' -f2 | remove_chars)
    wlan_lastassocstatus=$(echo -n "$airport_output" | egrep -i 'lastassocstatus' |  cut -d':' -f2 | remove_chars)i
    wlan_channel=$(echo -n "$airport_output"| egrep -i '[[:space:]]channel' |  cut -d':' -f2 | awk '{$1=$1;print}' | cut -d',' -f1 | remove_chars)i
    wlan_width=$(echo -n "$airport_output"| egrep -i '[[:space:]]channel' |  cut -d':' -f2 | awk '{$1=$1;print}' | cut -d',' -f2 | remove_chars)i
    wlan_spairportdatatype=$(system_profiler SPAirPortDataType)
    wlan_supportedphymode=$(echo -n "$wlan_spairportdatatype" | egrep -i "Supported PHY Modes" | cut -d':' -f2- | remove_chars)
    wlan_currentphymode=$(echo -n "$wlan_spairportdatatype" | egrep -i "PHY Mode:" | head -n1 | cut -d':' -f2- | remove_chars)

  else
    #set all values null as can not have an empty tag
    wlan_state="none"
    wlan_opmode="none"
    wlan_80211auth="none"
    wlan_linkauth="none"
    wlan_currentphymode="none"
    wlan_supportedphymode="none"
    wlan_channel=0i
    wlan_width=0i
    wlan_rssi=0i
    wlan_noise=0i
    wlan_snr=0i
    wlan_lasttxrate=0i
    wlan_maxrate=0i
    wlan_ssid=""
    wlan_bssid=""
    wlan_mcs=0i
    wlan_lastassocstatus=-1i
  fi
}

wlan_scan () {
  airport_output=$("$airport" -s -x)
  if [ -z "$airport_output" ]; then
    #echo -n "No airport output in scan"
    wlan_scan_on="false"
    wlan_scan_data="none"
    measurement="pansift_wlanscan"
    tagset=$(echo -n "wlan_scan_on=$wlan_scan_on")
    fieldset=$( echo -n "")
    results
  else
    # Need to migrate this to XML output and a data structure that Influx can ingest that includes taking in to account spaces in SSID hence XML
    #scandata="/tmp/airport.plist"
    scandata="$HOME/p3/airport.plist" #Need a better way to do the install location, assuming ~/p3 for now. 
    #test -f $scandata || touch $scandata
    #if [[ ! -e $scandata ]]; then
    #  touch $scandata
    #fi
    #echo $airport_output > tempfile && cp tempfile $scandata # This is a hack to wait for the completion of writing data
    printf "%s" "$airport_output" > "$scandata" &
    pid=$!
    wait $pid
    wlan_scan_on="true"
    plistbuddy="/usr/libexec/PlistBuddy"
    precount=$(
    "$plistbuddy" "${scandata}" -c "print ::" | # Extract array items
    cat -v |                                  # Convert from binary output to ascii
    grep -E "^\s{4}Dict" |                    # Search for top-level dictionaries
    wc -l |                                   # Count top-level dictionaries
    xargs                                     # Trim whitespace
    )
    count=$(expr "${precount}" - 1)
    for i in $(seq 0 "${count}")
    do
      wlan_scan_ssid=$("$plistbuddy" "$scandata" -c "print :$i:SSID_STR")
      wlan_scan_bssid=$("${plistbuddy}" "${scandata}" -c "print :$i:BSSID")
      #wlan_scan_bssid_tag=$(echo -n "$wlan_scan_bssid")  # BSSID should be a clean string as opposed to using SSID as a tag which needs to escape spaces with backslash \
        wlan_scan_channel=$("${plistbuddy}" "${scandata}" -c "print :$i:CHANNEL")i
      wlan_scan_rssi=$("${plistbuddy}" "${scandata}" -c "print :$i:RSSI")i
      wlan_scan_noise=$("${plistbuddy}" "${scandata}" -c "print :$i:NOISE")i
      wlan_scan_ht_secondary_chan_offset=$("${plistbuddy}" "${scandata}" -c "print :$i:HT_IE:HT_SECONDARY_CHAN_OFFSET")i
      measurement="pansift_wlanscan"
      #tagset=$(echo -n "wlan_scan_on=$wlan_scan_on,wlan_scan_bssid_tag=$wlan_scan_bssid_tag")
      tagset=$(echo -n "wlan_scan_on=$wlan_scan_on")
      fieldset=$( echo -n "wlan_scan_ssid=\"$wlan_scan_ssid\",wlan_scan_bssid=\"$wlan_scan_bssid\",wlan_scan_channel=$wlan_scan_channel,wlan_scan_rssi=$wlan_scan_rssi,wlan_scan_noise=$wlan_scan_noise,wlan_scan_ht_secondary_chan_offset=$wlan_scan_ht_secondary_chan_offset")
      timesuffix=$(expr 1000000000 + $i + 1) # This is to get around duplicates in Influx with measurement, tag, and timestamp the same. 
      timesuffix=${timesuffix:1} # We drop the leading "1" and end up with incrementing nanoseconds 9 digits long
      timestamp=$(date +%s)$timesuffix
      echo -ne "$measurement,$tagset $fieldset $timestamp\n" 
    done
  fi
}


http_checks () {
  # Yes we know this curl speed_download is single stream and not multithreaded/pipelined, it's just indicative of over X
  measurement="pansift_http"
  i=0
  IFS=","
  for host in $pansift_http_hosts_csv
  do
    if [ ! -z "$host" ]; then
      http_url=$(echo -n "$host" | remove_chars)
      curl_response=$(curl -A "$curl_user_agent" -k -s -o /dev/null -w "%{http_code}:%{speed_download}" -L "$host" --stderr - | remove_chars)
      http_status=$(echo -n "$curl_response" | cut -d':' -f1 | sed 's/^000/0/' | remove_chars)i
      http_speed_bytes=$(echo -n "$curl_response" | cut -d':' -f2)
      # bc doesn't print a leading zero and this confuses poor influx
      http_speed_megabits=$(echo "scale=3;($http_speed_bytes * 8) / 1000000" | bc -l | tr -d '\n' | sed 's/^\./0./' | remove_chars)
      tagset=$(echo -n "http_url=$http_url")
      fieldset=$( echo -n "http_status=$http_status,http_speed_megabits=$http_speed_megabits")
      timesuffix=$(expr 1000000000 + $i + 1) # This is to get around duplicates in Influx with measurement, tag, and timestamp the same.
      timesuffix=${timesuffix:1} # We drop the leading "1" and end up with incrementing nanoseconds 9 digits long
      timestamp=$(date +%s)$timesuffix
      echo -ne "$measurement,$tagset $fieldset $timestamp\n"
      ((i++))
    fi
  done
  IFS=$OLDIFS
}

# Telegraf: Need quotes for string field values but not in tags / also remember to use remove_chars for spaces and commas

results () {
  timestamp=$(date +%s)000000000
  echo -e "$measurement,$tagset $fieldset $timestamp\n"
}
while :; do
  case $1 in
    -m|--machine) 
      system_measure
      measurement="pansift_machine"            
      tagset=$(echo -n "product_name=$product_name,model_name=$model_name,model_identifier=$model_identifier,serial_number=$serial_number")
      fieldset=$(echo -n "product_version=\"$product_version\",boot_romversion=\"$boot_romversion\",smc_version=\"$smc_version\",memory=\"$memory\"")
      results
      ;;
    -n|--network) 
      internet_measure
      network_measure
      wlan_measure
      measurement="pansift_network"
      tagset=$(echo -n "internet_connected=$internet_connected,internet_dualstack=$internet_dualstack,ipv4_only=$ipv4_only,ipv6_only=$ipv6_only,locally_connected=$locally_connected,wlan_connected=$wlan_connected,wlan_state=$wlan_state,wlan_opmode=$wlan_opmode,wlan_80211auth=$wlan_80211auth,wlan_linkauth=$wlan_linkauth,wlan_currentphymode=$wlan_currentphymode,wlan_supportedphymode=$wlan_supportedphymode")            
      fieldset=$( echo -n "internet4_public_ip=\"$internet4_public_ip\",internet6_public_ip=\"$internet6_public_ip\",internet_asn=$internet_asn,dg4_ip=\"$dg4_ip\",dg6_ip=\"$dg6_ip\",dg4_interface=\"$dg4_interface\",dg6_interface=\"$dg6_interface\",dg4_interface_ether=\"$dg4_interface_ether\",dg6_interface_ether=\"$dg6_interface_ether\",dg4_response=$dg4_response,dg6_response=$dg6_response,dns4_primary=\"$dns4_primary\",dns6_primary=\"$dns6_primary\",dns4_query_response=$dns4_query_response,dns6_query_response=$dns6_query_response,wlan_rssi=$wlan_rssi,wlan_noise=$wlan_noise,wlan_snr=$wlan_snr,wlan_lasttxrate=$wlan_lasttxrate,wlan_maxrate=$wlan_maxrate,wlan_ssid=\"$wlan_ssid\",wlan_bssid=\"$wlan_bssid\",wlan_mcs=$wlan_mcs,wlan_lastassocstatus=$wlan_lastassocstatus,wlan_channel=$wlan_channel,wlan_width=$wlan_width")
      results
      ;;
    -s|--scan)
      # The reason we don't set the single measurement here is we are looping in the scan
      wlan_scan
      ;;
    -w|--web)
      # The reason we don't set the single measurement here is we are looping in the checks
      http_checks
      ;;
    *) break
  esac
  shift
done
