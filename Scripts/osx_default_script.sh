#!/usr/bin/env bash

# Pansift Telegraf input.exec script for writing influx measurements and tags

# set -e
# set -vx

# Note: We can't afford to have a comma or space out of place with InfluxDB ingestion in the line protocol
LDIFS=$IFS

script_name=$(basename "$0")
# Get configuration targets etc
PANSIFT_PREFERENCES="$HOME"/Library/Preferences/Pansift
source "$PANSIFT_PREFERENCES"/pansift.conf

if [[ ${#1} = 0 ]]; then
	echo "Usage: Pass one parameter -n|--network -m|--machine -t|--trace -s|--scan -w|--web -d|--dns"
	echo "Usage: ./$script_name -<parameter>"
	exit 0;
fi

utc_offset=$(date +%z)
airport="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
plistbuddy="/usr/libexec/PlistBuddy"
curl_path="/opt/local/bin/curl"
agent=()
agent+=("Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.82 Safari/537.36")
agent+=("Mozilla/5.0 (Macintosh; Intel Mac OS X 11.2; rv:86.0) Gecko/20100101 Firefox/86.0")
agent+=("Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15")
pick_user_agent=$[$RANDOM % ${#agent[@]}]
curl_user_agent=${agent[$pick_user_agent]}
#curl_user_agent="pansift.com/0.1"
#curl_user_agent="pansift-${PANSIFT_UUID}"

# These commands we want to and are happy to run each time as they may change frequently enough that we want to globally
# make decisions about them or reference them in more than one function or type of switch.
systemsoftware=$(sw_vers)
osx_mainline=$(echo -n "$systemsoftware" | grep -i "productversion" | cut -d':' -f2- | cut -d'.' -f1 | xargs)
network_interfaces=$(networksetup -listallhardwareports)

# Old versions of curl will fail with status 53 on SSL/TLS negotiation on newer hosts
# User really needs a newer curl binary but can also put defaults here
if test -f "$curl_path"; then
	curl_binary="/opt/local/bin/curl -m7 -A "$curl_user_agent" --no-keepalive "
else
	curl_binary="/usr/bin/curl -m7 -A "$curl_user_agent" --no-keepalive "
fi

# Note: Some of the squeezing and squishing could have been done with xargs!

remove_chars () {
	read data
	newdata=$(echo -n "$data" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r' | sed 's! !\\ !g')
	echo -n $newdata
}

remove_chars_except_commas () {
	# Beware this one, do not allow direct inclusion in tagsets or fieldsets
	read data
	newdata=$(echo -n "$data" | awk '{$1=$1;print}' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r' | sed 's! !\\ !g')
	echo -n $newdata
}


remove_chars_except_case () {
	read data
	newdata=$(echo -n "$data" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr -d '\r' | sed 's! !\\ !g')
	echo -n $newdata
}

remove_chars_except_spaces () {
	# This is for fieldset fields where there may be a space, as telegraf will add it's own backslash \ and if we already have one then we get "\\ "
	read data
	newdata=$(echo -n "$data" | awk '{$1=$1;print}' | tr ',' '.' | tr -s ' ' | tr '[:upper:]' '[:lower:]' | tr -d '\r')
	echo -n $newdata
}
remove_chars_delimit_colon () {
	# This is for fieldset fields with lists and we remove the comma just to be sure (and also *all* spaces)
	read data
	newdata=$(echo -n "$data" | awk '{$1=$1;print}' | tr ',' ':' | tr '[:upper:]' '[:lower:]' | tr -d '\r' | tr -d ' ')
	echo -n $newdata
}

timeout () { 
	perl -e 'alarm shift; exec @ARGV' "$@" 
}

get_test_hosts () {
	# Assumes dig in the system
	test_hosts=$(timeout 4 dig +time=3 +short TXT hosts.${PANSIFT_UUID}.ingest.pansift.com)
	if [[ $test_hosts =~ "h="[[:alnum:]] ]]; then
		hosts=$(echo -n "$test_hosts" | tr -d '"' | awk -F 'h=' '{print $2}' | awk -F '[[:alpha:]]=' '{print $1}' | remove_chars_except_commas)
	else
		test_hosts=$(timeout 4 dig +time=3 +short TXT hosts.default.ingest.pansift.com)
		if [[ $test_hosts =~ "h="[[:alnum:]] ]]; then
			hosts=$(echo -n "$test_hosts" | tr -d '"' | awk -F 'h=' '{print $2}' | awk -F '[[:alpha:]]=' '{print $1}' | remove_chars_except_commas)
		fi
	fi
	export PANSIFT_HOSTS_CSV=${hosts:=$PANSIFT_HOSTS_CSV}
}

ip_trace () {
	# Requires internet_measure to be called in advance
	internet_measure
	# This is not an explicit ASN path but rather the ASNs from a traceroute so it's not a BGP metric but a representation of AS zones 
	measurement="pansift_osx_paths"
	if [ "$internet4_connected" == "true" ]; then
		i=0
		IFS=","
		for host in $PANSIFT_HOSTS_CSV
		do
			if [[ -n "$host" ]]; then
				ip_trace=$(timeout 30 traceroute -I -w2 -n "$host" 2>/dev/null | grep -E "^ \d+ .*|^\d+ .*" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | awk '{ORS=";"}{print $1}' | sed 's/.$//' | remove_chars)
				target_host=$(echo -n "$host" | remove_chars)
				tagset=$(echo -n "internet4_connected=true,from_asn=$internet4_asn,destination=$target_host")
				fieldset=$( echo -n "utc_offset=\"$utc_offset\",ip_trace=\"$ip_trace\"")
				timesuffix=$(expr 1000000000 + $i + 1) # This is to get around duplicates in Influx with measurement, tag, and timestamp the same.
				timesuffix=${timesuffix:1} # We drop the leading "1" and end up with incrementing nanoseconds 9 digits long
				timestamp=$(date +%s)$timesuffix
				echo -ne "$measurement,$tagset $fieldset $timestamp\n"
				((i++))
			fi
		done
		IFS=$OLDIFS
	else
		tagset="internet4_connected=false,from_asn=AS0,destination=localhost"
		fieldset="utc_offset=\"$utc_offset\",ip_trace=\"none\""
		timestamp=$(date +%s)000000000
		echo -ne "$measurement,$tagset $fieldset $timestamp\n"
	fi
	# traceroute6 does not support ASN lookup -a
	if [ "$internet6_connected" == "true" ]; then
		i=0
		IFS=","
		for host in $PANSIFT_HOSTS_CSV
		do
			if [[ -n "$host" ]]; then
				ip_trace=$(timeout 30 traceroute6 -I -w2 -n "$host" 2>/dev/null | grep -E "^ \d+ .*|^\d+ .*" | grep -oE "(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))" | awk '{ORS=";"}{print $1}' | sed 's/.$//' | remove_chars)
				target_host=$(echo -n "$host" | remove_chars)
				tagset=$(echo -n "internet6_connected=true,from_asn=$internet6_asn,destination=$target_host")
				fieldset=$( echo -n "utc_offset=\"$utc_offset\",ip_trace=\"$ip_trace\"")
				timesuffix=$(expr 1000000000 + $i + 1) # This is to get around duplicates in Influx with measurement, tag, and timestamp the same.
				timesuffix=${timesuffix:1} # We drop the leading "1" and end up with incrementing nanoseconds 9 digits long
				timestamp=$(date +%s)$timesuffix
				echo -ne "$measurement,$tagset $fieldset $timestamp\n"
				((i++))
			fi
		done
		IFS=$OLDIFS
	else
		tagset="internet6_connected=false,from_asn=AS0,destination=localhost"
		fieldset="utc_offset=\"$utc_offset\",ip_trace=\"none\""
		timestamp=$(date +%s)000000000
		echo -ne "$measurement,$tagset $fieldset $timestamp\n"
	fi

}

system_measure () {
	#hostname=$(hostname | remove_chars)
	#username=$(echo -n "$USER" | remove_chars)
	# Uptime and uptime_format are already covered by the default plugin.
	#uptime=$(sysctl kern.boottime | cut -d' ' -f5 | cut -d',' -f1)

	product_name=$(echo -n "$systemsoftware" | egrep -i "productname" | cut -d':' -f2- | remove_chars_except_case)
	product_version=$(echo -n "$systemsoftware" | egrep -i "productversion" | cut -d':' -f2- | remove_chars_except_case)
	build_version=$(echo -n "$systemsoftware" | egrep -i "buildversion" | cut -d':' -f2- | remove_chars)

	systemprofile_sphardwaredatatype=$(system_profiler SPHardwareDataType)
	model_name=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "model name" | cut -d':' -f2- | remove_chars_except_case)
	model_identifier=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "model identifier" | cut -d':' -f2- | remove_chars_except_case)
	main_chip=$(echo -n "$systemprofile_sphardwaredatatype" | grep -Eqi "chip:" || { echo -n 'unknown'; exit 0;}; echo -n "$systemprofile_sphardwaredatatype" | grep -Ei "chip:" | cut -d':' -f2 | xargs | remove_chars_except_case)
	main_chip=${main_chip:="unknown"}
	memory=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "memory" | cut -d':' -f2- | remove_chars_except_spaces)
	boot_romversion=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "boot rom version|system firmware version" | cut -d':' -f2- | remove_chars_except_spaces)
	smc_version=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "smc version|os loader version" | cut -d':' -f2- | remove_chars_except_spaces)
	serial_number=$(echo -n "$systemprofile_sphardwaredatatype" | egrep -i "serial number" | cut -d':' -f2- | remove_chars)
}

network_measure () {
	product_version=$(echo -n "$systemsoftware" | egrep -i "productversion" | cut -d':' -f2- | remove_chars_except_case)
	product_sub_version=$(echo -n "$product_version" | cut -d'.' -f2 | remove_chars)
	if [[ "$osx_mainline" -ge 11 ]]; then
		netstat4_print_position=4 # 11.x Big Sur onwards
	elif [[ "$osx_mainline" -ge 10 ]]; then
		if [[ "$product_sub_version" -ge 15 ]]; then
			netstat4_print_position=4 # 10.15.x Catalina change?
		else
			netstat4_print_position=6 # 10.x 
		fi
	else 
		netstat4_print_position=6 # 10.x 
	fi
	netstat4=$(netstat -rn -f inet)
	netstat6=$(netstat -rn -f inet6)
	v6_defaultroute="default"
	v4_defaultroute="default"
	# Sequence here is important
	if echo -n "$netstat6" | grep -Eqi "^2000::\/3"; then
		v6_defaultroute="^2000::\/3"
	else
		dg6_ip=$(echo -n "$netstat6" | grep -Eqi "$v6_defaultroute" || { echo -n 'none'; exit 0;}; echo -n "$netstat6" | grep -Ei "$v6_defaultroute" | head -n1 | awk '{print $2}' | cut -d'%' -f1 | head -n1 | remove_chars)
		dg6_fullgw=$(echo -n "$netstat6" | grep -Eqi "$v6_defaultroute" || { echo -n 'none'; exit 0;}; echo -n "$netstat6" | grep -Ei "$v6_defaultroute" | head -n1 | awk '{print $2}' | head -n1 | remove_chars)
	fi
	if echo -n "$netstat4" | grep -Eqi "^0\/1"; then
		v4_defaultroute="^0\/1"
	fi
	dg4_ip=$(echo -n "$netstat4" | grep -Eqi "$v4_defaultroute" || { echo -n 'none'; exit 0;}; echo -n "$netstat4" | grep -Ei "$v4_defaultroute" | head -n1 | awk '{print $2}' | remove_chars)
	dg4_interface=$(echo -n "$netstat4" | grep -Eqi "$v4_defaultroute" || { echo -n 'none'; exit 0;}; echo -n "$netstat4" | grep -Ei "$v4_defaultroute" | head -n1 | awk -v x=$netstat4_print_position '{print $x}' | remove_chars)
	dg6_interface=$(echo -n "$netstat6" | grep -Eqi "$v6_defaultroute" || { echo -n 'none'; exit 0; }; echo -n "$netstat6" | grep -Ei "$v6_defaultroute" | head -n1 | awk '{print $2}'| remove_chars)

	# If the following are not set, set them now i.e. dg6_ip and dg6_fullgw
	temp_dg6_ip=$(echo -n "$netstat6" | grep -Eqi "^fe80.*$dg6_interface" || { echo -n 'none'; exit 0;}; echo -n "$netstat6" | grep -Ei "^fe80.*$dg6_interface" | head -n1 | awk '{print $2}' | cut -d'%' -f1 | head -n1 | remove_chars)
	dg6_ip=${dg6_ip:="$temp_dg6_ip"}
	temp_dg6_fullgw=$(echo -n "$netstat6" | grep -Eqi "^fe80.*$dg6_interface" || { echo -n 'none'; exit 0;}; echo -n "$netstat6" | grep -Ei "^fe80.*$dg6_interface" | head -n1 | awk '{print $2}' | head -n1 | remove_chars)
	dg6_fullgw=${dg6_fullgw:=$temp_dg6_fullgw}
	# 

	dg6_interface_device_only=$(echo -n "$dg6_interface" | grep -Eqi "%" || { echo -n "$dg6_interface"; exit 0;}; echo -n "$dg6_interface" | cut -d'%' -f2)
	if [ $dg6_interface == "none" ]; then
		dg6_interface_device_only="none"
	fi
	# Grabbing network interfaces from global 
	hardware_interfaces=$(echo -n "$network_interfaces" | awk -F ":" '/Hardware Port:|Device:/{print $2}' | paste -d',' - - )
	dg4_hardware_type=$(echo -n "$hardware_interfaces" | grep -qi "$dg4_interface" || { echo -n 'unknown'; exit 0; }; echo -n "$hardware_interfaces" | grep -i "$dg4_interface" | cut -d',' -f1 | xargs)
	dg6_hardware_type=$(echo -n "$hardware_interfaces" | grep -qi "$dg6_interface_device_only" || { echo -n 'unknown'; exit 0; }; echo -n "$hardware_interfaces" | grep -i "$dg6_interface_device_only" | cut -d',' -f1 | xargs)

	if [ ! "$dg4_ip" == "none" ]; then
		dg4_router_ether=$(arp -i "$dg4_interface" -n "$dg4_ip" | xargs | cut -d' ' -f4 | remove_chars)
		if [ "$dg4_router_ether" == "no" ]; then
			dg4_router_ether="none"
		fi
	else
		dg4_router_ether="none"
	fi
	if [ ! "$dg4_interface" == "none" ]; then
		dg4_interface_ether=$(ifconfig "$dg4_interface" | grep -Eqi "ether" || { echo -n 'none'; exit 0; }; ifconfig "$dg4_interface" | egrep ether | xargs | cut -d' ' -f2 | remove_chars)
	else
		dg4_interface_ether="none"
	fi
	if [ ! "$dg6_ip" == "none" ]; then
		dg6_router_ether=$(ndp -anr | egrep "$dg6_interface" | xargs | tr -s ' ' | cut -d' ' -f2 | remove_chars )
		if [ "$dg6_router_ether" == "no" ]; then
			dg6_router_ether="none"
		fi
	else
		dg6_router_ether="none"
	fi
	if [ ! "$dg6_interface" == "none" ]; then
		dg6_interface_ether=$(ifconfig "$dg6_interface_device_only" | grep -qi "ether" || { echo -n 'none'; exit 0; }; ifconfig "$dg6_interface_device_only" | grep -i "ether" | xargs | cut -d' ' -f2 | remove_chars)
	else
		dg6_interface_ether="none"
	fi

	# Could add to ping on Apple macOS -k for COS BK_SYS, BK, BE, RD, OAM, AV, RV, VI, VO and CTL
	# https://github.com/darwin-on-arm/xnu/blob/master/bsd/sys/kpi_mbuf.h search for MBUF_TC
	# MBUF_TC_BE (0) Best effort, normal class.
	# MBUF_TC_BK (1) Background, low priority or bulk traffic.
	# MBUF_TC_VI (2) Interactive video, constant bit rate, low latency.
	# MBUF_TC_VO (3) Interactive voice, constant bit rate, lowest latency.

	# We've possibly been hitting WLAN powersave in quiet times with dropping packets so increased count to 3
	# Removing the -o option as it skews towards the first packet which may take longer if device is asleep etc
	# Wait a maximum of -t5 seconds

	who_first="$(($RANDOM % 2))"
	# We got some interesting results in the IPv6 v IPv4 which is faster/latency tests so we want to randomize which one goes first so results are
	# not potentially skewed by sleeping radios, ARP, NDP etc...
	# Note: TODO: We have a timeout problem when timeout() then uses the last line which containts IPv6 or IPv4 address and not summary...
	if [ "$who_first" -eq 0 ]; then
		# echo "$who_first means IPv4 first"
		dg4_response=$(echo -n "$netstat4" | grep -qi default || { echo -n 0; exit 0; }; [[ ! "$dg4_ip" == "none" ]] && ping -t7 -c2 -k VO "$dg4_ip" 2>/dev/null | tail -n1 |  grep -i "avg" | cut -d' ' -f4 | cut -d'/' -f2 || echo -n 0)
		dg6_response=$(echo -n "$netstat6" | grep -qi default || { echo -n 0; exit 0; }; [[ ! "$dg6_ip" == "none" ]] && timeout 7 ping6 -c2 -k VO "$dg6_fullgw" 2>/dev/null | tail -n1 | grep -i "avg" | cut -d' ' -f4 | cut -d'/' -f2 || echo -n 0)
	else
		# echo "$who_first means IPv6 first"
		dg6_response=$(echo -n "$netstat6" | grep -qi default || { echo -n 0; exit 0; }; [[ ! "$dg6_ip" == "none" ]] && timeout 7 ping6 -c2 -k VO "$dg6_fullgw" 2>/dev/null | tail -n1 | grep -i "avg" | cut -d' ' -f4 | cut -d'/' -f2 || echo -n 0)
		dg4_response=$(echo -n "$netstat4" | grep -qi default || { echo -n 0; exit 0; }; [[ ! "$dg4_ip" == "none" ]] && ping -t7 -c2 -k VO "$dg4_ip" 2>/dev/null | tail -n1 | grep -i "avg" | cut -d' ' -f4 | cut -d'/' -f2 || echo -n 0)
	fi


	if [[ "$dg4_response" > 0 ]] || [[ "$dg6_respone" > 0 ]]; then
		locally_connected="true"
	else
		# There's a scenario here where the local gateway or VPN will not answer ICMP queries :(
		locally_connected="false"
	fi 
	if [[ "$dg4_response" > 0 ]]; then
		locally4_connected="true"
	fi
	if [[ "$dg6_response" > 0 ]]; then
		locally6_connected="true"
	fi


}

dns_cache_rr_measure () {

	# Note: On a per bucket basis we could debate about how often the target hosts would change?
	# This is in regards to the cardinality of using $target_host from PANSIFT_HOSTS_CSV as tags
	# rather than in the fieldset depending upon uniqueness. Also, the simplicity of querying by
	# tags versus field values. For now, the $target host can be tags as max 5 and will change
	# infrequently on a per-bucket basis

	measurement="pansift_osx_dns_cache"
	dns4_cache_query_response=0.0
	dns6_cache_query_response=0.0
	RESOLV=/etc/resolv.conf
	if test -f "$RESOLV"; then
		dns4_primary=$(cat /etc/resolv.conf | grep -q 'nameserver.*\..*\..*\.' || { echo -n 'none'; exit 0; }; cat /etc/resolv.conf | grep 'nameserver.*\..*\..*\.' | head -n1 | cut -d' ' -f2 | remove_chars)
		dns6_primary=$(cat /etc/resolv.conf | grep -q 'nameserver.*:' || { echo -n 'none'; exit 0; }; cat /etc/resolv.conf | grep 'nameserver.*:' | head -n1 | cut -d' ' -f2 | remove_chars)
		if [ $dns4_primary != "none" ]; then
			# Loop through the hosts
			i=0
			IFS=","
			for host in $PANSIFT_HOSTS_CSV
			do
				if [[ -n "$host" ]]; then
					target_host=$(echo -n "$host" | remove_chars)
					dns4_cache_query_output=$(timeout 4 dig -4 +time=3 +tries=1 @"$dns4_primary" "$target_host")
					# dns4_cache_query_response=$(echo -n "$dns4_cache_query_output" | grep -m1 -i "query time" | cut -d' ' -f4 | remove_chars)
					dns4_cache_query_response=$(echo -n "$dns4_cache_query_output" | grep -m1 -i 'Query time:' | grep -oEe '[0-9]+' | remove_chars)
					dns4_cache_query_status=$(echo -n "$dns4_cache_query_output" | grep -m1 -i ' status: ' | cut -d, -f2 | cut -d: -f2 | remove_chars_except_case)
					if [[ -n "$dns4_cache_query_response" ]] && [[ "$dns4_cache_query_response" == "0" ]]; then
						# Successful fast query probably local or wired so rewriting response to 1 msec
						dns4_cache_query_response=1.0
					fi
					tagset=$(echo -n "ip_version=4,locally4_connected=${locally4_connected:=false},locally_connected=$locally_connected,dns4_primary_found=true,destination=$target_host")
					fieldset=$(echo -n "utc_offset=\"$utc_offset\",dns4_primary=\"$dns4_primary\",dns4_cache_query_response=${dns4_cache_query_response:=0.0},dns4_cache_query_status=\"${dns4_cache_query_status:=PS_DIG4_MISSING_STATUS}\"")
					timesuffix=$(expr 1000000000 + $i + 1) # This is to get around duplicates in Influx with measurement, tag, and timestamp the same.
					timesuffix=${timesuffix:1} # We drop the leading "1" and end up with incrementing nanoseconds 9 digits long
					timestamp=$(date +%s)$timesuffix
					echo -ne "$measurement,$tagset $fieldset $timestamp\n"
					((i++))
				fi
			done
			IFS=$OLDIFS
		else
			dns4_primary="none"
			target_host="none"
			tagset="ip_version=4,locally4_connected=${locally4_connected:=false},locally_connected=$locally_connected,dns4_primary_found=false,destination=$target_host"
			fieldset=$(echo -n "utc_offset=\"$utc_offset\",dns4_primary=\"$dns4_primary\",dns4_cache_query_response=0.0,dns4_cache_query_status=\"${dns4_cache_query_status:=PS_DIG4_MISSING_STATUS}\"")
			timestamp=$(date +%s)000000004
			echo -ne "$measurement,$tagset $fieldset $timestamp\n"
		fi
		if [ $dns6_primary != "none" ]; then
			# Loop through the hosts
			i=0
			IFS=","
			for host in $PANSIFT_HOSTS_CSV
			do
				if [[ -n "$host" ]]; then
					target_host=$(echo -n "$host" | remove_chars)
					dns6_cache_query_output=$(timeout 4 dig -6 AAAA +time=3 +tries=1 @"$dns6_primary" "$target_host")
					# dns6_cache_query_response=$(echo -n "$dns6_cache_query_output" | grep -m1 -i "query time" | cut -d' ' -f4 | remove_chars)
					dns6_cache_query_response=$(echo -n "$dns6_cache_query_output" | grep -m1 -i 'Query time:' | grep -oEe '[0-9]+' | remove_chars)
					dns6_cache_query_status=$(echo -n "$dns6_cache_query_output" | grep -m1 -i ' status: ' | cut -d, -f2 | cut -d: -f2 | remove_chars_except_case)
					if [[ -n "$dns6_cache_query_response" ]] && [[ "$dns6_cache_query_response" == "0" ]]; then
						# Successful fast query probably local or wired so rewriting response to 1 msec
						dns6_cache_query_response=1.0
					fi
					tagset=$(echo -n "ip_version=6,locally6_connected=${locally6_connected:=false},locally_connected=$locally_connected,dns6_primary_found=true,destination=$target_host")
					fieldset=$(echo -n "utc_offset=\"$utc_offset\",dns6_primary=\"$dns6_primary\",dns6_cache_query_response=${dns6_cache_query_response:=0.0},dns6_cache_query_status=\"${dns6_cache_query_status:=PS_DIG6_MISSING_STATUS}\"")
					timesuffix=$(expr 1000000000 + $i + 1) # This is to get around duplicates in Influx with measurement, tag, and timestamp the same.
					timesuffix=${timesuffix:1} # We drop the leading "1" and end up with incrementing nanoseconds 9 digits long
					timestamp=$(date +%s)$timesuffix
					echo -ne "$measurement,$tagset $fieldset $timestamp\n"
					((i++))
				fi
			done
			IFS=$OLDIFS
		else
			dns6_primary="none"
			target_host="none"
			tagset="ip_version=6,locally6_connected=${locally6_connected:=false},locally_connected=$locally_connected,dns6_primary_found=false,destination=$target_host"
			fieldset=$(echo -n "utc_offset=\"$utc_offset\",dns6_primary=\"$dns6_primary\",dns6_cache_query_response=0.0,dns6_cache_query_status=\"${dns6_cache_query_status:=PS_DIG6_MISSING_STATUS}\"")
			timestamp=$(date +%s)000000006
			echo -ne "$measurement,$tagset $fieldset $timestamp\n"
		fi
	else
		# If no RESOLV settings found
		dns6_primary="none"
		dns4_primary="none"
		target_host="none"
		tagset4="ip_version=4,locally4_connected=${locally4_connected:=false},locally_connected=$locally_connected,dns4_primary_found=false,destination=$target_host"
		fieldset4=$( echo -n "utc_offset=\"$utc_offset\",dns4_primary=\"$dns4_primary\",dns4_cache_query_response=0.0")
		tagset6="ip_version=6,locally6_connected=${locally6_connected:=false},locally_connected=$locally_connected,dns6_primary_found=false,destination=$target_host"
		fieldset6=$(echo -n "utc_offset=\"$utc_offset\",dns6_primary=\"$dns6_primary\",dns6_cache_query_response=0.0")
		timestamp4=$(date +%s)000000004
		timestamp6=$(date +%s)000000006
		echo -ne "$measurement,$tagset4 $fieldset4 $timestamp4\n"
		echo -ne "$measurement,$tagset6 $fieldset6 $timestamp6\n"
	fi
}


dns_random_rr_measure () {

	# dns_query_host=$(uuidgen) # This seems to be failing to gain enough entropy when this script is run repetitively
	# dns_query_domain="doesnotexist.pansift.com"
	# dns_query="$dns_query_host.$dns_query_domain"

	dns4_query_response=0.0
	dns6_query_response=0.0
	RESOLV=/etc/resolv.conf
	if test -f "$RESOLV"; then
		dns4_primary=$(cat /etc/resolv.conf | grep -q 'nameserver.*\..*\..*\.' || { echo -n 'none'; exit 0; }; cat /etc/resolv.conf | grep 'nameserver.*\..*\..*\.' | head -n1 | cut -d' ' -f2 | remove_chars)
		dns6_primary=$(cat /etc/resolv.conf | grep -q 'nameserver.*:' || { echo -n 'none'; exit 0; }; cat /etc/resolv.conf | grep 'nameserver.*:' | head -n1 | cut -d' ' -f2 | remove_chars)
		if [[ "$dns4_primary" != "none" ]]; then
			dns4_query_output=$(dig -4 +time=3 +tries=1 @"$dns4_primary" $(uuidgen).doesnotexist.pansift.com)
			# dns4_query_response=$(echo -n "$dns4_query_output" | grep -m1 -i "query time" | cut -d' ' -f4 | remove_chars)
			dns4_query_response=$(echo -n "$dns4_query_output" | grep -m1 -i 'Query time:' | grep -oEe '[0-9]+' | remove_chars)
			if [[ -n "$dns4_query_response" ]] && [[ "$dns4_query_response" == "0" ]]; then
				# Successful fast query probably local or wired so rewriting response to 1 msec
				dns4_query_response=1.0
			fi
			dns4_query_response=${dns4_query_response:=0.0}
		else
			dns4_query_response=0.0
		fi
		if [[ "$dns6_primary" != "none" ]]; then
			dns6_query_output=$(dig -6 +time=3 +tries=1 @"$dns6_primary" $(uuidgen).doesnotexist.pansift.com)
			# dns6_query_response=$(echo -n "$dns6_query_output" | grep -m1 -i "query time" | cut -d' ' -f4 | remove_chars)
			dns6_query_response=$(echo -n "$dns6_query_output" | grep -m1 -i 'Query time:' | grep -oEe '[0-9]+' | remove_chars)
			if [[ -n "$dns6_query_response" ]] && [[ "$dns6_query_response" == "0" ]]; then
				# Successful fast query probably local or wired so rewriting response to 1 msec
				# This seems to be happening too often?
				# echo "Using $dns6_primary to ask about $dns_query with response of $dns6_query_response from output of $dns6_query_output"
				dns6_query_response=1.0
			fi
			dns6_query_response=${dns6_query_response:=0.0}
		else 
			dns6_query_response=0.0
		fi
	else
		dns4_primary="none"
		dns6_primary="none"
	fi
}


internet_measure () {
	# We need basic ICMP response times from lighthouse too?
	#
	internet4_connected=$(ping -o -c2 -t10 $PANSIFT_ICMP4_TARGET > /dev/null 2>&1 || { echo -n "false"; exit 0;}; echo -n "true")
	internet6_connected=$(timeout 10 ping6 -o -c2 $PANSIFT_ICMP6_TARGET > /dev/null 2>&1 || { echo -n "false"; exit 0;}; echo -n "true")
	internet_connected="false" # Default to be overwritten below
	internet_dualstack="false" # "
	ipv4_only="false" # "
	ipv6_only="false" # "
	internet4_public_ip="none"
	internet6_public_ip="none"
	# internet_asn="0i"
	internet4_asn="0i"
	internet6_asn="0i"

	if [ "$internet4_connected" == "true" ] || [ "$internet6_connected" == "true" ]; then
		internet_connected="true"
	else
		internet_connected="false"
		internet4_public_ip="none"
		internet6_public_ip="none"
	fi
	if [ "$internet4_connected" == "true" ] && [ "$internet6_connected" == "true" ]; then
		ipv4_only="false"
		ipv6_only="false"
		internet_dualstack="true"
		lighthouse4=$(timeout 5 $curl_binary -sN -4 -L -i "$PANSIFT_LIGHTHOUSE" 2>&1 || exit 0)
		lighthouse6=$(timeout 5 $curl_binary -sN -6 -L -i "$PANSIFT_LIGHTHOUSE" 2>&1 || exit 0)
		# internet_asn=$(echo -n "$lighthouse4" | grep -qi "x-pansift-client-asn" || { echo -n '0'; exit 0;}; echo -n "$lighthouse4" | grep -i "x-pansift-client-asn" | cut -d' ' -f2 | remove_chars )i
		internet4_asn=$(echo -n "$lighthouse4" | grep -qi "x-pansift-client-asn" || { echo -n '0'; exit 0;}; echo -n "$lighthouse4" | grep -i "x-pansift-client-asn" | cut -d' ' -f2 | remove_chars )i
		internet6_asn=$(echo -n "$lighthouse6" | grep -qi "x-pansift-client-asn" || { echo -n '0'; exit 0;}; echo -n "$lighthouse6" | grep -i "x-pansift-client-asn" | cut -d' ' -f2 | remove_chars )i
		internet4_public_ip=$(echo -n "$lighthouse4" | grep -qi "x-pansift-client-ip" || { echo -n 'none'; exit 0;}; echo -n "$lighthouse4" | grep -i "x-pansift-client-ip" | cut -d' ' -f2 | remove_chars )
		internet6_public_ip=$(echo -n "$lighthouse6" | grep -qi "x-pansift-client-ip" || { echo -n 'none'; exit 0;}; echo -n "$lighthouse6" | grep -i "x-pansift-client-ip" | cut -d' ' -f2 | remove_chars )
	fi
	if [ "$internet4_connected" == "true" ] && [ "$internet6_connected" == "false" ]; then
		ipv4_only="true"
		ipv6_only="false"
		internet_dualstack="false"
		lighthouse4=$(timeout 5 $curl_binary -sN -4 -L -i "$PANSIFT_LIGHTHOUSE" 2>&1 || exit 0)
		# internet_asn=$(echo -n "$lighthouse4" | egrep -qi "x-pansift-client-asn" || { echo -n '0'; exit 0;}; echo -n "$lighthouse4" | egrep -i "x-pansift-client-asn" | cut -d' ' -f2 | remove_chars )i
		internet4_asn=$(echo -n "$lighthouse4" | grep -qi "x-pansift-client-asn" || { echo -n '0'; exit 0;}; echo -n "$lighthouse4" | grep -i "x-pansift-client-asn" | cut -d' ' -f2 | remove_chars )i
		internet4_public_ip=$(echo -n "$lighthouse4" | egrep -qi "x-pansift-client-ip" || { echo -n 'none'; exit 0;}; echo -n "$lighthouse4" | egrep -i "x-pansift-client-ip" | cut -d' ' -f2 | remove_chars )
		internet6_public_ip="none"
	fi
	if [ "$internet4_connected" == "false" ] && [ "$internet6_connected" == "true" ]; then
		ipv4_only="false"
		ipv6_only="true"
		internet_dualstack="false"
		lighthouse6=$(timeout 5 $curl_binary -sN -6 -L -i "$PANSIFT_LIGHTHOUSE" 2>&1 || exit 0)
		# internet_asn=$(echo -n "$lighthouse6" | egrep -qi "x-pansift-client-asn" || { echo -n '0'; exit 0;}; echo -n "$lighthouse6" | egrep -i "x-pansift-client-asn" | cut -d' ' -f2 | remove_chars )i
		internet6_asn=$(echo -n "$lighthouse6" | grep -qi "x-pansift-client-asn" || { echo -n '0'; exit 0;}; echo -n "$lighthouse6" | grep -i "x-pansift-client-asn" | cut -d' ' -f2 | remove_chars )i
		internet4_public_ip="none"
		internet6_public_ip=$(echo -n "$lighthouse6" | egrep -qi "x-pansift-client-ip" || { echo -n 'none'; exit 0;}; echo -n "$lighthouse6" | egrep -i "x-pansift-client-ip" | cut -d' ' -f2 | remove_chars )
	fi
}

local_ips () {
	# We need internet_measure() and network_measure() to run first so we can know our public IPv6 address!
	if [ ! "$dg4_interface" == "none" ]; then
		dg4_interface_details=$(ifconfig "$dg4_interface")
		dg4_interface_details_inet=$(echo -n "$dg4_interface_details" | grep -i "inet ")
		dg4_local_ip=$(echo -n "$dg4_interface_details_inet" | grep -qi "inet " || { echo -n 'none'; exit 0; }; echo -n "$dg4_interface_details_inet" | grep -i "inet " | awk '{print $2}'| remove_chars)
		dg4_local_netmask=$(echo -n "$dg4_interface_details_inet" | grep -qi "inet " || { echo -n 'none'; exit 0; }; echo -n "$dg4_interface_details_inet" | grep -i "inet " | awk '{print $4}'| remove_chars)
	else
		dg4_local_ip="none"
		dg4_local_netmask="none"
	fi

	if [ ! "$dg6_interface_device_only" == "none" ]; then
		dg6_interface_details=$(ifconfig "$dg6_interface_device_only")
		# We know there may be multiple IPv6 addresses so first look for the one mapping to public if connectivity allows, then look for the next one in reverse order, so most likely to be the temporary
		# If none, we should get the fe80 address...
		dg6_interface_details_temp=$(echo -n "$dg6_interface_details" | grep -i "inet6" | head -n1 )
		dg6_interface_details_inet6=$(echo -n "$dg6_interface_details" | grep -i "$internet6_public_ip")
		dg6_interface_details_inet6=${dg6_interface_details_inet6:=$dg6_interface_details_temp}
	else
		dg6_interface_details_inet6="none"
	fi
	if [[ ! "$dg6_interface_details_inet6" == "none" ]]; then 
		dg6_local_ip=$(echo -n "$dg6_interface_details_inet6" | grep -qi "inet6" || { echo -n 'none'; exit 0; }; echo -n "$dg6_interface_details_inet6" | grep -i "inet6" | awk '{print $2}'| cut -d '%' -f1 | remove_chars)
		dg6_local_prefixlen=$(echo -n "$dg6_interface_details_inet6" | grep -qi "inet6" || { echo -n 'none'; exit 0; }; echo -n "$dg6_interface_details_inet6" | grep -i "inet6" | awk '{print $4}'| remove_chars)
	else
		dg6_interface_details_inet6=$(echo -n "$dg6_interface_details" | grep -i "inet6" | tail -r)
		dg6_local_ip=$(echo -n "$dg6_interface_details_inet6" | grep -qi "inet6" || { echo -n 'none'; exit 0; }; echo -n "$dg6_interface_details_inet6" | grep -i "inet6" | head -n1 | awk '{print $2}' | cut -d '%' -f1 | remove_chars)
		dg6_local_prefixlen=$(echo -n "$dg6_interface_details_inet6" | grep -qi "inet6" || { echo -n 'none'; exit 0; }; echo -n "$dg6_interface_details_inet6" | grep -i "inet6" | head -n1 | awk '{print $4}'| remove_chars)
	fi
}

wlan_measure () {
	# Need to add a separate PlistBuddy to extract keys rather than below as is cleaner + can get NSS (Number of Spatial Streams)
	airport_output=$($airport -I)
	# Here we grab more information about the local airport card or about the currently connected network (not available above)
	wlan_sp_airport_data_type=$(system_profiler SPAirPortDataType)
	wlan_connected=$(echo -n "$airport_output" | grep -q 'AirPort: Off' && echo -n 'false' || echo -n 'true')
	if [[ $wlan_connected == "true" ]] && [[ ! -z "$wlan_connected" ]]; then
		wlan_state=$(echo -n "$airport_output" | egrep -i '[[:space:]]state' | cut -d':' -f2- | remove_chars) 
		# There are states of init (problematic for stats), authenticating, associating (also problematic), scanning, running
		if [[ $wlan_state == "scanning" ]] || [[ $wlan_state == "running" ]]; then
			wlan_state="running" # This is increasing the cardinality needlessly, can revert if queries actually need scanning time
			wlan_op_mode=$(echo -n "$airport_output"| egrep -i '[[:space:]]op mode' | cut -d':' -f2- | remove_chars)
			# In an enviornment with the Airport on and no known or previously connected networks this needs to be set
			if [[ ${#wlan_op_mode} == 0 ]]; then
				wlan_op_mode="none"
			fi
			wlan_rssi=$(echo -n "$airport_output" | egrep -i '[[:space:]]agrCtlRSSI' | cut -d':' -f2- | remove_chars)
			wlan_noise=$(echo -n "$airport_output" | egrep -i '[[:space:]]agrCtlNoise' | cut -d':' -f2- | remove_chars)
			wlan_snr=$(var=$(( $(( $wlan_noise * -1)) - $(( $wlan_rssi * -1)) )); echo -n $var)i
			# wlan_spatial_streams doesn't work for NSS with 802.11ax on 2.4GHz
			# because of mathematical operation, add back in i
			wlan_rssi="$wlan_rssi"i
			wlan_noise="$wlan_noise"i
			wlan_last_tx_rate=$(echo -n "$airport_output"| egrep -i '[[:space:]]lastTxRate' | cut -d':' -f2- | remove_chars)i
			wlan_max_rate=$(echo -n "$airport_output" | egrep -i '[[:space:]]maxRate' | cut -d':' -f2- | remove_chars)i
			wlan_ssid=$(echo -n "$airport_output" | egrep -i '[[:space:]]ssid' | cut -d':' -f2- | awk '{$1=$1;print}')
			# Missing information due to bugs in macOS and the airport CLI command both for -I and -x
			# Bugs related to no MCS in 2.4GHz on 11.x and also on 802.1ax missing MCS
			# We also want to add in the phy-type here as a string so we can pivot off it in DB
			wlan_missing_info=$(echo -n "$wlan_sp_airport_data_type" | grep -A10 "$wlan_ssid" | head -10)
			wlan_phy_mode=$(echo -n "$wlan_missing_info" | grep -i 'PHY Mode:' | cut -d':' -f2 | xargs)
			wlan_mcs=-1 # Default just to set it in case we change the if/else logic below and mess up
			if [[ "$wlan_phy_mode" == "802.11ax" ]]; then
				# If 802.11ax then we need to use the system_profiler :(
				wlan_mcs=$(echo -n "$wlan_missing_info" | grep -i 'MCS Index:' | cut -d':' -f2 | xargs)
			elif [[ "$wlan_channel" -lt 15 ]] && [[ $osx_mainline == 11 ]] ; then
				# Here we have an OSX bug where the CLI reports MCS 0 even when MCS can be 15 when on the 2.4GHz range i.e. channels 1-14
				wlan_mcs=$(echo -n "$wlan_missing_info" | grep -i 'MCS Index:' | cut -d':' -f2 | xargs)
			else
				wlan_mcs=$(echo -n "$airport_output"| egrep -i '[[:space:]]mcs' | cut -d':' -f2 | remove_chars)
			fi
			wlan_mcs_i="$wlan_mcs"i
			wlan_mcs_i=${wlan_mcs_i:=-1i}
			# Bug in Monterey airport -I is missing BSSID in 12.4 and 12.5 :( it requires sudo as per 
			# https://www.reddit.com/r/MacOS/comments/qlqhld/airport_reports_blank_bssid_since_monterey/
			if [[ "$osx_mainline" -ge 12 ]]; then
				wlan_bssid=""
			else
				wlan_bssid=$(echo -n "$airport_output" | egrep -i '[[:space:]]bssid' | awk '{$1=$1;print}' | cut -d' ' -f2)
			fi
			wlan_channel=$(echo -n "$airport_output"| egrep -i '[[:space:]]channel' |  cut -d':' -f2 | awk '{$1=$1;print}' | cut -d',' -f1 | remove_chars)
			wlan_channel_i="$wlan_channel"i
			wlan_80211_auth=$(echo -n "$airport_output"| egrep -i '[[:space:]]802\.11 auth' |  cut -d':' -f2 | remove_chars)
			wlan_link_auth=$(echo -n "$airport_output" | egrep -i '[[:space:]]link auth' |  cut -d':' -f2 | remove_chars)
			wlan_last_assoc_status=$(echo -n "$airport_output" | egrep -i 'lastassocstatus' |  cut -d':' -f2 | remove_chars)i

		# Here we need to add airport -I -x for PLIST and then extract the NSS if available. Also can direct extract channel width value as BANDWIDTH
		# Turns out that (other than using native API) the airport -I vs -Ix give additional information
		airport_more_data="$PANSIFT_LOGS"/airport-more-info.plist #Need a better way to do the install location, assuming ~/p3 for now.
		airport_info_xml=$($airport -Ix)
		printf "%s" "$airport_info_xml" > "$airport_more_data" &
		pid=$!
		wait $pid
		if [[ "$wlan_op_mode" != "none" ]] && [[ $osx_mainline == 11 ]] && [[ "$wlan_channel" -lt 15 ]]; then
			wlan_number_spatial_streams=0i
			wlan_width=0i
		elif [[ "$wlan_op_mode" != "none" ]] && [[ $osx_mainline == 10 ]]; then
			wlan_number_spatial_streams=0i
			wlan_width=0i
    elif [[ "$wlan_op_mode" == "none" ]]; then
      wlan_number_spatial_streams=0i
      wlan_width=0i
		else 
			wlan_number_spatial_streams=$("$plistbuddy" "${airport_more_data}" -c "print NSS" 2>/dev/null| remove_chars)i
		fi
		if [[ "$wlan_number_spatial_streams" == "i" ]]; then
			wlan_number_spatial_streams=0i
		fi
		# Let's get the current frequency BAND and WIDTH from the Channel Flags : Donal 201023
      wlan_channel_flags=$("${plistbuddy}" "${airport_more_data}" -c "print CHANNEL_FLAGS" 2>/dev/null)
      wlan_channel_flags_binary=$(echo "obase=2;$wlan_channel_flags" | bc)
      wlan_channel_flags_length=${#wlan_channel_flags_binary}
      wlan_channel_flags_binary_pad_bits=$(printf "%016.0f" "$wlan_channel_flags_binary")
      wlan_channel_flags_last_bits=${wlan_channel_flags_binary_pad_bits: -5}
      wlan_channel_flags_two_ghz_bit=${wlan_channel_flags_last_bits:1:1}
      wlan_channel_flags_five_ghz_bit=${wlan_channel_flags_last_bits:0:1}
      wlan_channel_flags_six_ghz_bit=${wlan_channel_flags_binary_pad_bits:2:1}
      wlan_channel_flags_channel_width_twenty_mhz=${wlan_channel_flags_last_bits:3:1}
      wlan_channel_flags_channel_width_forty_mhz=${wlan_channel_flags_last_bits:2:1}
      wlan_channel_flags_channel_width_eighty_mhz=${wlan_channel_flags_binary_pad_bits:5:1}
      wlan_channel_flags_channel_width_onesixty_mhz=${wlan_channel_flags_binary_pad_bits:4:1}
      wlan_channel_flags_channel_width_threetwenty_mhz=${wlan_scan_channel_flags_binary_pad_bits:3:1}
      if [[ $wlan_channel_flags_two_ghz_bit == "1" ]]; then
        wlan_channel_flags_band=2
      fi
      if [[ $wlan_channel_flags_five_ghz_bit == "1" ]]; then
        wlan_channel_flags_band=5
      fi
			if [[ $wlan_channel_flags_six_ghz_bit == "1" ]]; then
      # if [[ $wlan_channel_flags_two_ghz_bit == "0" ]] && [[ $wlan_channel_flags_five_ghz_bit == "0" ]]; then
        wlan_channel_flags_band=6
      fi
			wlan_channel_flags_band=${wlan_channel_flags_band:=-1}i # Be careful with adding i's if already defined?
		# wlan_width=$("$plistbuddy" "${airport_more_data}" -c "print BANDWIDTH" | remove_chars)i
		# There is still a bug presenting in 11.X with 802.11ax for spatial streams even on 5GHz where we can't get data as set to 0 in airport -Ix
		width_increment=$(echo -n "$airport_output"| egrep -i '[[:space:]]channel' |  cut -d':' -f2 | awk '{$1=$1;print}' | cut -d',' -f2 | remove_chars)
		if [[ "$width_increment" == 1 ]] || [[ "$width_increment" == 40 ]]; then
			wlan_width=40i
		elif [[ "$width_increment" == 2 ]] || [[ "$width_increment" == 80 ]]; then
			wlan_width=80i
		elif [[ "$width_increment" == 3 ]] || [[ "$width_increment" == 160 ]]; then
			wlan_width=160i
		else
			wlan_width=20i
		fi

      # Alternate: Get the WIDTH from the Apple CHANNEL_FLAGS
      if [[ $wlan_channel_flags_channel_width_twenty_mhz == "1" ]]; then
        wlan_channel_flags_width=20i
      fi
      if [[ $wlan_channel_flags_channel_width_forty_mhz == "1" ]]; then
        wlan_channel_flags_width=40i
      fi
      if [[ $wlan_channel_flags_channel_width_eighty_mhz == "1" ]]; then
        wlan_channel_flags_width=80i
      fi
      if [[ $wlan_channel_flags_channel_width_onesixty_mhz == "1" ]]; then
        wlan_channel_flags_width=160i
      fi
      if [[ $wlan_channel_flags_channel_width_threetwenty_mhz == "1" ]]; then
        wlan_channel_flags_width=320i
      fi
      wlan_width=${wlan_channel_flags_width:=-1i}

		wlan_current_phy_mode=$(echo -n "$wlan_sp_airport_data_type" | egrep -i "PHY Mode:" | head -n1 | cut -d':' -f2- | remove_chars)
		wlan_supported_phy_mode=$(echo -n "$wlan_sp_airport_data_type" | egrep -i "Supported PHY Modes" | cut -d':' -f2- | remove_chars)
		wlan_supported_channels=$(echo -n "$wlan_sp_airport_data_type" | egrep -i "Supported Channels:" | head -n1 | cut -d':' -f2- | remove_chars_delimit_colon)
		# We need to take in to account the following 2 states of init / associating where much of the data is unavailable.
	elif [[ "$wlan_state" == "init" ]] || [[ "$wlan_state" == "associating" ]] || [[ "$wlan_state" == "authenticating" ]]; then
		wlan_op_mode="none"
		wlan_80211_auth="none"
		wlan_link_auth="none" # Though this is available for init
		wlan_current_phy_mode="none"
		wlan_channel_i=0i
		wlan_width=-1i # Can we default to 20 (20MHz) i.e. does 0 mean 20, what about .ax?
		wlan_rssi=0i
		wlan_noise=0i
		wlan_snr=0i
		wlan_last_tx_rate=0i
		wlan_max_rate=0i
		wlan_ssid=""
		wlan_bssid=""
		wlan_phy_mode=""
		wlan_mcs_i=-1i # MCS can be 0 as per https://mcsindex.com/
		wlan_last_assoc_status=-1i
		wlan_number_spatial_streams=0i
		wlan_supported_phy_mode=$(echo -n "$wlan_sp_airport_data_type" | egrep -i "Supported PHY Modes" | cut -d':' -f2- | remove_chars)
		wlan_supported_channels=$(echo -n "$wlan_sp_airport_data_type" | egrep -i "Supported Channels:" | head -n1 | cut -d':' -f2- | remove_chars_delimit_colon)
		wlan_channel_flags_band=${wlan_channel_flags_band:=-1i}
	else
		# This can happen in a VM where there is no wlan_state but the airport tool still works and returns blank
		wlan_state="unknown"
		wlan_op_mode="none"
		wlan_80211_auth="none"
		wlan_link_auth="none" # Though this is available for init
		wlan_current_phy_mode="none"
		wlan_supported_phy_mode="none"
		wlan_channel_i=0i
		wlan_width=-1i # Can we default to 20 (20MHz) i.e. does 0 mean 20, what about .ax?
		wlan_rssi=0i
		wlan_noise=0i
		wlan_snr=0i
		wlan_last_tx_rate=0i
		wlan_max_rate=0i
		wlan_ssid=""
		wlan_bssid=""
		wlan_phy_mode=""
		wlan_mcs_i=-1i # MCS can be 0 as per https://mcsindex.com/
		wlan_last_assoc_status=-1i
		wlan_number_spatial_streams=0i
		wlan_supported_channels=""
		wlan_channel_flags_band=${wlan_channel_flags_band:=-1i}
		fi
	else
		# set all values null as can not have an empty tag and safer than in the fieldset for everything?
		# Note: We can do this with variable expansion such as ${wlan_state:='none'} in the tagset/fieldset
		wlan_state="none"
		wlan_op_mode="none"
		wlan_80211_auth="none"
		wlan_link_auth="none"
		wlan_current_phy_mode="none"
		wlan_supported_phy_mode="none"
		wlan_channel_i=0i
		wlan_width=-1i # Can we default to 20 (20MHz) i.e. does 0 mean 20, what about .ax?
		wlan_rssi=0i
		wlan_noise=0i
		wlan_snr=0i
		wlan_last_tx_rate=0i
		wlan_max_rate=0i
		wlan_ssid=""
		wlan_bssid=""
		wlan_phy_mode=""
		wlan_mcs_i=-1i # MCS can be 0 as per https://mcsindex.com/
		wlan_last_assoc_status=-1i
		wlan_number_spatial_streams=0i
		wlan_supported_channels=""
   	wlan_channel_flags_band=${wlan_channel_flags_band:=-1i}
	fi
}

wlan_scan () {
	airport_output=$("$airport" -s -x)
	if [[ -z "$airport_output" ]]; then
		# echo -n "No airport output in scan"
		wlan_scan_on="false"
		# wlan_scan_data="none"
		measurement="pansift_osx_wlanscan"
		tagset=$(echo -n "wlan_scan_on=$wlan_scan_on")
		fieldset=$( echo -n "utc_offset=\"$utc_offset\",wlan_on=false")
		results
	else
		# Need to migrate this to XML output and a data structure that Influx can ingest that includes taking in to account spaces in SSID hence XML
		#scandata="/tmp/airport.plist"
		scandata="$PANSIFT_LOGS"/airport-scan.plist #Need a better way to do the install location, assuming ~/p3 for now. 
		#test -f $scandata || touch $scandata
		#if [[ ! -e $scandata ]]; then
		#  touch $scandata
		#fi
		#echo $airport_output > tempfile && cp tempfile $scandata # This is a hack to wait for the completion of writing data
		printf "%s" "$airport_output" > "$scandata" &
		pid=$!
		wait $pid
		wlan_scan_on="true"
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
			wlan_scan_ssid=$("${plistbuddy}" "${scandata}" -c "print :$i:SSID_STR" 2>/dev/null)
			wlan_scan_bssid=$("${plistbuddy}" "${scandata}" -c "print :$i:BSSID" 2>/dev/null)
			wlan_scan_cc=$("${plistbuddy}" "${scandata}" -c "print :$i:80211D_IE:IE_KEY_80211D_COUNTRY_CODE" 2>/dev/null)
			#wlan_scan_bssid_tag=$(echo -n "$wlan_scan_bssid")  # BSSID should be a clean string as opposed to using SSID as a tag which needs to escape spaces with backslash \
			wlan_scan_channel=$("${plistbuddy}" "${scandata}" -c "print :$i:CHANNEL" 2>/dev/null)i
      wlan_scan_channel_flags=$("${plistbuddy}" "${scandata}" -c "print :$i:CHANNEL_FLAGS" 2>/dev/null)
      wlan_scan_channel_flags_binary=$(echo "obase=2;$wlan_scan_channel_flags" | bc)
      wlan_scan_channel_flags_length=${#wlan_scan_channel_flags_binary}
      wlan_scan_channel_flags_binary_pad_bits=$(printf "%016.0f" "$wlan_scan_channel_flags_binary")
      wlan_scan_channel_flags_last_bits=${wlan_scan_channel_flags_binary_pad_bits: -5}
      wlan_scan_channel_flags_two_ghz_bit=${wlan_scan_channel_flags_last_bits:1:1}
      wlan_scan_channel_flags_five_ghz_bit=${wlan_scan_channel_flags_last_bits:0:1}
      wlan_scan_channel_flags_six_ghz_bit=${wlan_scan_channel_flags_binary_pad_bits:2:1}
      wlan_scan_channel_flags_channel_width_twenty_mhz=${wlan_scan_channel_flags_last_bits:3:1}
      wlan_scan_channel_flags_channel_width_forty_mhz=${wlan_scan_channel_flags_last_bits:2:1}
      wlan_scan_channel_flags_channel_width_eighty_mhz=${wlan_scan_channel_flags_binary_pad_bits:5:1}
      wlan_scan_channel_flags_channel_width_onesixty_mhz=${wlan_scan_channel_flags_binary_pad_bits:4:1}
      wlan_scan_channel_flags_channel_width_threetwenty_mhz=${wlan_scan_channel_flags_binary_pad_bits:3:1}
			wlan_scan_rssi=$("${plistbuddy}" "${scandata}" -c "print :$i:RSSI" 2>/dev/null)i
			wlan_scan_noise=$("${plistbuddy}" "${scandata}" -c "print :$i:NOISE" 2>/dev/null)i
			# Noise is lacking in Sonoma 14.x XML output
			if [[ "$wlan_scan_noise" == "i" ]]; then
				wlan_scan_noise=0i
			fi
			wlan_scan_vht_op_channel_center_frequency_seg0=$("${plistbuddy}" "${scandata}" -c "print :$i:VHT_OP:CHANNEL_CENTER_FREQUENCY_SEG0" 2>/dev/null)i
			wlan_scan_vht_op_channel_center_frequency_seg1=$("${plistbuddy}" "${scandata}" -c "print :$i:VHT_OP:CHANNEL_CENTER_FREQUENCY_SEG1" 2>/dev/null)i
			wlan_scan_vht_op_channel_width=$("${plistbuddy}" "${scandata}" -c "print :$i:VHT_OP:CHANNEL_WIDTH" 2>/dev/null)i
			wlan_scan_ht_secondary_chan_offset=$("${plistbuddy}" "${scandata}" -c "print :$i:HT_IE:HT_SECONDARY_CHAN_OFFSET" 2>/dev/null)i
			# The following "xargs" is because we can get null bytes from plist binary data and bash doesn't like them
			wlan_scan_he_op_info_center_channel_freq_seg0=$("${plistbuddy}" "${scandata}" -c "print :$i:HE_OP_IE:6GHZ_OP_INFO_CENTER_CHANNEL_FREQ_SEG0" 2>/dev/null)i 
			wlan_scan_he_op_info_center_channel_freq_seg1=$("${plistbuddy}" "${scandata}" -c "print :$i:HE_OP_IE:6GHZ_OP_INFO_CENTER_CHANNEL_FREQ_SEG1" 2>/dev/null)i
			wlan_scan_he_op_bss_color=$("${plistbuddy}" "${scandata}" -c "print :$i:HE_OP_IE:BSS_COLOR" 2>/dev/null)i
			#
			# Explicit defaults rather than {:=} expansion? Be careful with expansion on loops!!!!
			# 
			unset wlan_scan_channel_flags_width # Reset in loop to prevent expansion with "i" on not null below
			unset wlan_scan_channel_flags_band # Reset in loop to prevent expansion with "i" on not null below
			unset wlan_scan_80211n
			unset wlan_scan_80211ac
			unset wlan_scan_80211ax
			# Get the WIDTH from the Apple CHANNEL_FLAGS
			if [[ $wlan_scan_channel_flags_channel_width_twenty_mhz == "1" ]]; then
				wlan_scan_channel_flags_width=20
			fi
			if [[ $wlan_scan_channel_flags_channel_width_forty_mhz == "1" ]]; then
				wlan_scan_channel_flags_width=40
			fi
			if [[ $wlan_scan_channel_flags_channel_width_eighty_mhz == "1" ]]; then
				wlan_scan_channel_flags_width=80
			fi
			if [[ $wlan_scan_channel_flags_channel_width_onesixty_mhz == "1" ]]; then
				wlan_scan_channel_flags_width=160
			fi
			if [[ $wlan_scan_channel_flags_channel_width_threetwenty_mhz == "1" ]]; then
				wlan_scan_channel_flags_width=320
			fi
			wlan_scan_channel_flags_width=${wlan_scan_channel_flags_width:=0}i
			# Note: The following may or may not be present hence starting to move to the channel flags above.
			# You also need to know if previously a/b/g and ht = n, vht = ac, and he = ax
			# Get the BAND from the Apple CHANNEL_FLAGS (Remember that ac is only 5GHz not 2GHz)
			if [[ $wlan_scan_channel_flags_two_ghz_bit == "1" ]]; then
				wlan_scan_channel_flags_band=2
			fi
			if [[ $wlan_scan_channel_flags_five_ghz_bit == "1" ]]; then
				wlan_scan_channel_flags_band=5
			fi
			if [[ $wlan_scan_channel_flags_six_ghz_bit == "1" ]]; then
      #if [[ $wlan_scan_channel_flags_two_ghz_bit == "0" ]] && [[ $wlan_scan_channel_flags_five_ghz_bit == "0" ]]; then
        wlan_scan_channel_flags_band=6
      fi
      wlan_scan_channel_flags_band=${wlan_scan_channel_flags_band:=-1}i
			if [ $wlan_scan_ht_secondary_chan_offset == "i" ]; then
				wlan_scan_ht_secondary_chan_offset="0i"
				wlan_scan_80211n="false"
			else 
				wlan_scan_80211n="true"
			fi
			if [ $wlan_scan_vht_op_channel_center_frequency_seg0 == "i" ]; then
				wlan_scan_vht_op_channel_center_frequency_seg0="0i"
				wlan_scan_80211ac="false"
			elif [[ $wlan_scan_channel_flags_five_ghz_bit == "1" ]] && [[ $wlan_scan_vht_op_channel_center_frequency_seg0 != "i" ]]; then
				wlan_scan_80211ac="true"
			else
				wlan_scan_80211ac="false"
			fi
			if [ $wlan_scan_vht_op_channel_center_frequency_seg1 == "i" ]; then
				wlan_scan_vht_op_channel_center_frequency_seg1="0i"
			fi
			if [ $wlan_scan_he_op_bss_color == "i" ]; then
				wlan_scan_80211ax="false"
			else
				wlan_scan_80211ax="true"
			fi
			if [ $wlan_scan_he_op_info_center_channel_freq_seg0 == "i" ]; then
				wlan_scan_he_op_info_center_channel_freq_seg0="0i"
			fi
			if [ $wlan_scan_he_op_info_center_channel_freq_seg1 == "i" ]; then
				wlan_scan_he_op_info_center_channel_freq_seg1="0i"
			fi
      wlan_scan_80211n=${wlan_scan_80211n:=false}
      wlan_scan_80211ac=${wlan_scan_80211ac:=false}
      wlan_scan_80211ax=${wlan_scan_80211ax:=false}
			if [[ $wlan_scan_vht_op_channel_width == "i" ]]; then
				wlan_scan_vht_op_channel_width="0i"
			fi
			measurement="pansift_osx_wlanscan"
			#tagset=$(echo -n "wlan_scan_on=$wlan_scan_on,wlan_scan_bssid_tag=$wlan_scan_bssid_tag")
			tagset=$(echo -n "wlan_scan_on=$wlan_scan_on")
			fieldset=$( echo -n "utc_offset=\"$utc_offset\",wlan_scan_ssid=\"$wlan_scan_ssid\",wlan_scan_bssid=\"$wlan_scan_bssid\",wlan_scan_channel=$wlan_scan_channel,wlan_scan_rssi=$wlan_scan_rssi,wlan_scan_noise=${wlan_scan_noise:=0i},wlan_scan_vht_op_channel_center_frequency_seg0=$wlan_scan_vht_op_channel_center_frequency_seg0,wlan_scan_vht_op_channel_center_frequency_seg1=$wlan_scan_vht_op_channel_center_frequency_seg1,wlan_scan_vht_op_channel_width=$wlan_scan_vht_op_channel_width,wlan_scan_cc=\"${wlan_scan_cc:=none}\",wlan_scan_ht_secondary_chan_offset=$wlan_scan_ht_secondary_chan_offset,wlan_scan_channel_flags_width=${wlan_scan_channel_flags_width:=0i},wlan_scan_channel_flags_band=${wlan_scan_channel_flags_band:=-1i},wlan_scan_he_op_info_center_channel_freq_seg0=$wlan_scan_he_op_info_center_channel_freq_seg0,wlan_scan_he_op_info_center_channel_freq_seg1=$wlan_scan_he_op_info_center_channel_freq_seg1")
			timesuffix=$(expr 1000000000 + $i + 1) # This is to get around duplicates in Influx with measurement, tag, and timestamp the same. 
			timesuffix=${timesuffix:1} # We drop the leading "1" and end up with incrementing nanoseconds 9 digits long
			timestamp=$(date +%s)$timesuffix
			# echo "Bits of next: $wlan_scan_channel_flags_binary_pad_bits"
			# We could just call the "results" function here instead of echo explicit?
			echo -ne "$measurement,$tagset $fieldset $timestamp\n" 
			# echo "Band: $wlan_scan_channel_flags_band"
			# echo "Channel width: $wlan_scan_channel_flags_width"
			# echo "wlan_scan_80211n: $wlan_scan_80211n"
			# echo "wlan_scan_80211ac: $wlan_scan_80211ac"
			# echo "wlan_scan_80211ax: $wlan_scan_80211ax"
		done
	fi
}


http_checks () {
	# Only IPv4?
	# Yes we know this curl speed_download is single stream and not multithreaded/pipelined, it's just indicative of over X
	# Note: for the unix tool "bc" the special scale variable only works on division, hence the extra multiplication and division
	measurement="pansift_osx_http"
	i=0
	IFS=","
	for host in $PANSIFT_HOSTS_CSV
	do
		if [[ -n "$host" ]]; then
			http_url=$(echo -n "$host" | remove_chars)
			target_host="https://"$host
			# Max time for operation -m doesn't work
			# Was having variable expansion issues with $curl_binary here so just calling curl directly with random agent.
			# It's borking on an illegal character returned from a time out + also the remove-chars... curl_response contains 
			# bad data when using $curl_binary
			curl_response=$(timeout 30 curl -A "$curl_user_agent" --no-keepalive -4 -k -s -o /dev/null -w "%{time_namelookup}:%{time_connect}:%{time_appconnect}:%{time_pretransfer}:%{time_starttransfer}:%{time_total}:%{size_download}:%{http_code}:%{speed_download}" -L "$target_host" 2>&1)
			curl_response=${curl_response:="0"}
			http_time_namelookup=$(echo -n "$curl_response" | cut -d':' -f1 | remove_chars)
			http_time_connect=$(echo -n "$curl_response" | cut -d':' -f2 | remove_chars)
			http_time_appconnect=$(echo -n "$curl_response" | cut -d':' -f3 | remove_chars)
			http_time_pretransfer=$(echo -n "$curl_response" | cut -d':' -f4 | remove_chars)
			http_time_starttransfer=$(echo -n "$curl_response" | cut -d':' -f5 | remove_chars)
			http_time_total=$(echo -n "$curl_response" | cut -d':' -f6 | remove_chars)
			http_size_download=$(echo -n "$curl_response" | cut -d':' -f7 | remove_chars)
			http_size_megabytes=$(echo "scale=3;($http_size_download  / 1000000)" | bc -l | tr -d '\n' | sed 's/^\./0./' | remove_chars)
			http_size_kilobytes=$(echo "scale=1;($http_size_download  / 1000)" | bc -l | tr -d '\n' | sed 's/^\./0./' | remove_chars)
			http_status=$(echo -n "$curl_response" | cut -d':' -f8 | sed 's/^000/0/' | remove_chars)i
			http_speed_bytes=$(echo -n "$curl_response" | cut -d':' -f9 | remove_chars)
			# bc doesn't print a leading zero and this confuses poor influx
			http_speed_megabits=$(echo "scale=3;($http_speed_bytes * 8) / 1000000" | bc -l | tr -d '\n' | sed 's/^\./0./' | remove_chars)
			# http_ttfb changing to scale=3 to catch very fast i.e. us v ms setup on fast links. Also, why not divide by 1000 instead of * 10000 / 10 ??
			http_ttfb=$(echo "scale=3;(($http_time_connect - $http_time_namelookup) * 10000) / 10;" | bc -l | tr -d '\n' | sed 's/^\./0./' | remove_chars)
      if [ 1 -eq "$(echo "${http_ttfb} < 0" | bc)" ]; then # IF for example IPv4 is down we are doing maths with a lookup that might work but connect doesn't and results in negative values
        http_ttfb=0
      fi
			tagset=$(echo -n "ip_version=4,http_url=$http_url")
			fieldset=$( echo -n "utc_offset=\"$utc_offset\",http_time_namelookup=${http_time_namelookup:=0},http_time_connect=${http_time_connect:=0},http_time_appconnect=${http_time_appconnect:=0},http_time_pretransfer=${http_time_pretransfer:=0},http_time_starttransfer=${http_time_starttransfer:=0},http_time_total=${http_time_total:=0},http_size_megabytes=${http_size_megabytes:=0},http_size_kilobytes=${http_size_kilobytes:=0},http_ttfb=${http_ttfb:=0},http_status=${http_status:=0i},http_speed_megabits=${http_speed_megabits:=0}")
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
			measurement="pansift_osx_machine"            
			tagset=$(echo -n "product_name=$product_name,model_name=$model_name,model_identifier=$model_identifier,serial_number=$serial_number,main_chip=$main_chip")
			fieldset=$(echo -n "utc_offset=\"$utc_offset\",product_version=\"$product_version\",boot_romversion=\"$boot_romversion\",smc_version=\"$smc_version\",memory=\"$memory\"")
			results
			;;
		-n|--network) 
			internet_measure # No dependency, max 10s ping(s) and 14s cURL
			network_measure # Can take 10s
			dns_random_rr_measure # Can take 6s for random UUID on v4 and v6
			local_ips # dependency on both prior internet_measure and network_measure
			wlan_measure
			# echo "Channel band: $wlan_channel_flags_band"
			measurement="pansift_osx_network"
			tagset=$(echo -n "internet_connected=$internet_connected,internet_dualstack=$internet_dualstack,ipv4_only=$ipv4_only,ipv6_only=$ipv6_only,locally_connected=$locally_connected,wlan_connected=$wlan_connected,wlan_state=$wlan_state,wlan_op_mode=$wlan_op_mode,wlan_supported_phy_mode=$wlan_supported_phy_mode") 
			# TODO: We need to make better use of the default assignment e.g. dg6_response=${dg6_response:=0.0} for all variables
			fieldset=$( echo -n "utc_offset=\"$utc_offset\",internet4_public_ip=\"$internet4_public_ip\",internet6_public_ip=\"$internet6_public_ip\",internet4_asn=$internet4_asn,internet6_asn=$internet6_asn,dg4_ip=\"$dg4_ip\",dg4_router_ether=\"$dg4_router_ether\",dg6_router_ether=\"$dg4_router_ether\",dg6_ip=\"$dg6_ip\",dg4_hardware_type=\"$dg4_hardware_type\",dg6_hardware_type=\"$dg6_hardware_type\",dg4_interface=\"$dg4_interface\",dg6_interface=\"$dg6_interface\",dg6_interface_device_only=\"$dg6_interface_device_only\",dg4_interface_ether=\"$dg4_interface_ether\",dg6_interface_ether=\"$dg6_interface_ether\",dg4_local_ip=\"$dg4_local_ip\",dg4_local_netmask=\"$dg4_local_netmask\",dg4_response=${dg4_response:=0},dg6_local_ip=\"$dg6_local_ip\",dg6_local_prefixlen=\"$dg6_local_prefixlen\",dg6_response=${dg6_response:=0},dns4_primary=\"$dns4_primary\",dns6_primary=\"$dns6_primary\",dns4_query_response=$dns4_query_response,dns6_query_response=$dns6_query_response,wlan_rssi=$wlan_rssi,wlan_noise=$wlan_noise,wlan_snr=$wlan_snr,wlan_last_tx_rate=$wlan_last_tx_rate,wlan_max_rate=$wlan_max_rate,wlan_ssid=\"$wlan_ssid\",wlan_bssid=\"$wlan_bssid\",wlan_phy_mode=\"$wlan_phy_mode\",wlan_mcs=$wlan_mcs_i,wlan_number_spatial_streams=${wlan_number_spatial_streams:=0i},wlan_last_assoc_status=$wlan_last_assoc_status,wlan_channel=$wlan_channel_i,wlan_channel_flags_band=${wlan_channel_flags_band:=-1i},wlan_width=${wlan_width:=-1i},wlan_current_phy_mode=\"$wlan_current_phy_mode\",wlan_supported_channels=\"$wlan_supported_channels\",wlan_80211_auth=\"$wlan_80211_auth\",wlan_link_auth=\"$wlan_link_auth\"")
			results
			;;
		-s|--scan)
			# The reason we don't set the single measurement here is we are looping in the scan
			wlan_scan
			;;
		-w|--web)
			# The reason we don't set the single measurement here is we are looping in the checks
			get_test_hosts # Can take 8-10s
			http_checks
			;;
		-t|--trace)
			# The reason we don't set the single measurement here is we are looping in the checks
			get_test_hosts # Can take 8-10s
			ip_trace
			;;
		-d|--dns)
			# The reason we don't set the single measurement here is we are looping in the checks
			get_test_hosts # Can take 8-10s
			network_measure # Needed to set locally_connected boolean tag, can take 10s
			dns_cache_rr_measure # 3s per host checked
			;;
		*) break
	esac
	shift
done
