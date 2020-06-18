#!/bin/bash

if [ -z "$resourceGroup" ]; then
    echo "No resource group secret-vars.txt"
    exit 1
fi

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$secretsDir" ]; then
    echo "No Secrets directory specified in secret-vars.txt"
    exit 1
fi

SKIP_JUMP_BOX_SHUTDOWN=false
if [ "$1" == "--skip-jump-box-shutdown" ]; then
	SKIP_JUMP_BOX_SHUTDOWN=true
fi

echo "Starting jump box..."
if ! az vm start -g $resourceGroup -n jump ; then
	echo "Unable to start the jump box in $resourceGroup" 
	exit 1
fi

ip=$(az network public-ip show --resource-group $resourceGroup --name jump-public-ip --query "{address: ipAddress}" 2>/dev/null | jq -r .address )
if [ -z "$ip" ]; then
	echo "No IP address found for the jump box in $resourceGroup"
	exit 1
fi

echo "Found IP: $ip"

eval `ssh-agent`
ssh-add /$deploymentDir/$secretsDir/ssh_rsa
scp ./convertMongodbExporterServiceFile.sh nucleus@$ip:/home/nucleus
ssh -A nucleus@$ip bash ./convertMongodbExporterServiceFile.sh

if [ "$SKIP_JUMP_BOX_SHUTDOWN" != "true" ]; then
	echo "Deallocating jumpbox..."
	az vm deallocate -g $resourceGroup -n jump
	if [ $? -ne 0 ]; then
		echo "An error has occurred deallocating jumpbox." 1>&2
		exit 1
	fi
fi
