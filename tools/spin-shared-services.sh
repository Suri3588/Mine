#!/usr/bin/env bash

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

if [ -z "$modulesDir" ]; then
    echo "No Modules directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$projectsDir" ]; then
    echo "No Projects directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$terraformDir" ]; then
    echo "No Terraform directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$secretsDir" ]; then
    echo "No Secrets directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$subscriptionId" ]; then
    echo "No subscription ID specified in secret-vars.txt"
    exit 1
fi

if [ -z "$dnsPrefix" ]; then
    echo "No DNS prefix specified secret-vars.txt"
    exit 1
fi

if [ -z "$deployDomain" ]; then
    echo "No deploy domain specified secret-vars.txt"
    exit 1
fi

if [ -z "$isSharedService" ]; then
    echo "The isSharedService is not set, run extract-secrets.sh"
    exit 1
fi

while [ -n "$1" ]; do
	case "$1" in
        "--skip-jump-box-shutdown")
            skipShutdown=--skip-jump-box-shutdown
            shift
            ;;
        "--remote-state")
            remoteState=--remote-state
            shift
            ;;
        *)
            echo "Error: Unknown command: $1"
            exit 1
	esac
done

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
pushd $scriptDir > /dev/null

./setup-deployment.sh
if [ $? -ne 0 ]; then
    exit 1
fi

./provision-terraform.sh $skipShutdown $remoteState
if [ $? -ne 0 ]; then
    exit 1
fi

./create-kubernetes-config.sh
if [ $? -ne 0 ]; then
    exit 1
fi

./deploy-kubernetes.sh
if [ $? -ne 0 ]; then
    exit 1
fi

./upload-app-insights.sh
if [ $? -ne 0 ]; then
    exit 1
fi

ip=$(az network public-ip show --resource-group $resourceGroup-ip --name $dnsPrefix-public-ip --query "{address: ipAddress}" 2>/dev/null | jq -r .address )
if [ -z "$ip" ]; then
    echo "No IP address found for $dnsPrefix-public-ip in $resourceGroup-ip"
    exit 1
fi

echo ""
echo "The spin of $resourceGroup is complete"
echo ""
