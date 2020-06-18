#!/usr/bin/env bash

which=${1,,}
ip1=$2
ip2=$3

updateDns() {
    record=$1

    az network dns record-set a create -g Management -z $dnsZone -n $record --ttl 3600 1>/dev/null
    az network dns record-set a add-record -g Management -z $dnsZone -n $record -a $ip1 1>/dev/null

    if [ -n "$ip2" ]; then
        az network dns record-set a add-record -g Management -z $dnsZone -n $record -a $ip2 1>/dev/null
    fi

    echo "DNS A record updated: $1.$dnsZone"
}

if [ -z "$resourceGroup" ]; then
    echo "No resource group secret-vars.txt"
    exit 1
fi

if [ -z "$dnsZone" ]; then
    echo "No DNS Zone specified in secret-vars.txt"
    exit
fi

if [ -z "$dnsPrefix" ]; then
    echo "No DNS Prefix specified in secret-vars.txt"
    exit
fi

if [ "$which" == "oldsystem" ]; then
    if [ -z "$ip1" ]; then
        ip1=$(az network public-ip show --resource-group $resourceGroup --name lb1-nic1 --query "{address: ipAddress}" 2>/dev/null | jq -r .address )
        if [ -z "$ip1" ]; then
            echo "No IP address found for lb1-nic1 in $resourceGroup"
            exit 1
        fi
    fi
    echo "Found IP address for lb1-nic1: $ip1"

    if [ -z "$ip2" ]; then
        ip2=$(az network public-ip show --resource-group $resourceGroup --name lb2-nic1 --query "{address: ipAddress}" 2>/dev/null | jq -r .address )
        if [ -n "$ip2" ]; then
            echo "Found IP address for lb2-nic1: $ip2"
        fi
    fi

elif [ "$which" == "newsystem" ]; then
    if [ -z "$ip1" ]; then
        ip1=$(az network public-ip show --resource-group $resourceGroup-ip --name $dnsPrefix-public-ip --query "{address: ipAddress}" 2>/dev/null | jq -r .address )
        if [ -z "$ip1" ]; then
            echo "No IP address found for $dnsPrefix-public-ip in $resourceGroup-ip"
            exit 1
        fi
    fi
    echo "Found IP address for $dnsPrefix-public-ip: $ip1"
else
    echo "the first parameter must be either 'oldsystem' or 'newsystem'"
    exit 1
fi

updateDns $dnsPrefix 
updateDns $dnsPrefix-1 
updateDns $dnsPrefix-2 
updateDns $dnsPrefix-3 

if [ "$which" == "oldsystem" ]; then
    updateDns kibana-$dnsPrefix

elif [ "$which" == "newsystem" ]; then
    updateDns linkerd-$dnsPrefix
fi

exit 0