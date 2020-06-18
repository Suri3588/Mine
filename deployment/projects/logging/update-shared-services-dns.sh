#!/usr/bin/env bash

SUBDOMAIN_SUFFIX="$1"
DNS_ZONE="$2"

IP_ADDRESS="104.42.32.69"

updateDns() {
    local record=$1
	local ip=$2

    az network dns record-set a create -g Management -z $DNS_ZONE -n $record --ttl 3600 1>/dev/null
    az network dns record-set a add-record -g Management -z $DNS_ZONE -n $record -a $ip 1>/dev/null

    echo "DNS A record updated: $1.$dnsZone"
}

updateDns "grafana-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"
updateDns "alertmanager-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"
updateDns "kibana-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"
updateDns "linkerd-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"
updateDns "prometheus-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"
updateDns "elasticsearch-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"

