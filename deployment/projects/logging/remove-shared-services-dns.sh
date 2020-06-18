#!/usr/bin/env bash

SUBDOMAIN_SUFFIX="$1"
DNS_ZONE="$2"

IP_ADDRESS="104.42.32.69"

removeDns() {
    local record=$1
	local ip=$2

	az network dns record-set a remove-record --resource-group Management --zone-name $DNS_ZONE --record-set-name $record --ipv4-address $ip

    echo "DNS A record removed: $record.$DNS_ZONE"
}

removeDns "grafana-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"
removeDns "alertmanager-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"
removeDns "kibana-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"
removeDns "linkerd-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"
removeDns "prometheus-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"
removeDns "elasticsearch-$SUBDOMAIN_SUFFIX" "$IP_ADDRESS"

