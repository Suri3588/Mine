#!/usr/bin/env bash

# NOTE: This script is effectively a no-op, if the logging directory hasn't been copied
#       over to the deployment directory. Therefore, there is no harm in always calling
#       it from kubegroup-k8s.tf, regardless of deployment type.

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$projectsDir" ]; then
    echo "No projects directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$dnsPrefix" ]; then
    echo "No DNS Prefix specified in secret-vars.txt"
    exit 1
fi

updateFile() {
    local FILE_PATH="$1"
    local IP_ADDRESS="$2"

    if ! grep -q "IP_ADDRESS" "$FILE_PATH" ; then
        echo "Unable to locate IP_ADDRESS in $FILE_PATH"
        exit 1
    fi

    sed -i "s/^IP_ADDRESS=.*/IP_ADDRESS=\"$IP_ADDRESS\"/g" "$FILE_PATH"
    if [ $? -ne 0 ]; then
        echo "An error occurred updating the IP_ADDRESS in $FILE_PATH"
        exit 1
    fi

    echo "The file: $FILE_PATH has been updated"
}

if [ -d "$deploymentDir/$projectsDir/logging" ]; then
    externalIngressIp=$(az network public-ip show --resource-group $resourceGroup-ip --name $dnsPrefix-public-ip --query "{address: ipAddress}" 2> /dev/null | jq -r .address )
    if [ -z "$externalIngressIp" ]; then
        echo "Unable to get the external ingress IP"
        exit 1
    fi

    echo "Found Public IP: $externalIngressIp"

    updateFile "$deploymentDir/$projectsDir/logging/update-shared-services-dns.sh" "$externalIngressIp"
    updateFile "$deploymentDir/$projectsDir/logging/remove-shared-services-dns.sh" "$externalIngressIp"
fi

