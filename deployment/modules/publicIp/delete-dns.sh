#!/usr/bin/env bash

if [ -z "$dnsZone" ]; then
    echo "No DNS Zone specified in secret-vars.txt"
    exit
fi

if [ -z "$dnsPrefix" ]; then
    echo "No DNS Prefix specified in secret-vars.txt"
    exit
fi

az network dns record-set a delete --resource-group Management --zone-name $dnsZone --name $dnsPrefix --yes 1>/dev/null
if [ $? -eq 0 ]; then
    echo "DNS A record deleted: $dnsPrefix.$dnsZone"
fi

az network dns record-set a delete --resource-group Management --zone-name $dnsZone --name $dnsPrefix-1 --yes 1>/dev/null
if [ $? -eq 0 ]; then
    echo "DNS A record deleted: $dnsPrefix-1.$dnsZone"
fi

az network dns record-set a delete --resource-group Management --zone-name $dnsZone --name $dnsPrefix-2 --yes 1>/dev/null
if [ $? -eq 0 ]; then
    echo "DNS A record deleted: $dnsPrefix-2.$dnsZone"
fi

az network dns record-set a delete --resource-group Management --zone-name $dnsZone --name $dnsPrefix-3 --yes 1>/dev/null
if [ $? -eq 0 ]; then
    echo "DNS A record deleted: $dnsPrefix-3.$dnsZone"
fi

az network dns record-set a delete --resource-group Management --zone-name $dnsZone --name linkerd-$dnsPrefix --yes 1>/dev/null
if [ $? -eq 0 ]; then
    echo "DNS A record deleted: linkerd-$dnsPrefix.$dnsZone"
fi

