#!/usr/bin/env bash

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$terraformDir" ]; then
    echo "No Terraform directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

remoteState=false
skipShutdown=false

while [ -n "$1" ]; do
	case "$1" in
        "--remote-state")
            remoteState=true
            shift
            ;;
        "--skip-jump-box-shutdown")
            skipShutdown=true
            shift
            ;;
        *)
            echo "Error: Unknown command: $1"
            exit 1
	esac
done

# use azure.remote as needed
if [ -f "$deploymentDir/$terraformDir/azure.tf" ]; then
    rm $deploymentDir/$terraformDir/azure.tf
fi

if [ "$remoteState" == "false" ]; then
    cp $deploymentDir/$terraformDir/azure.tf.local $deploymentDir/$terraformDir/azure.tf
else
    cp $deploymentDir/$terraformDir/azure.tf.remote $deploymentDir/$terraformDir/azure.tf
fi

# create the azure resources for the kubernetes deployment via terraform
pushd $deploymentDir/$terraformDir  > /dev/null
echo "yes" | terraform init
if [ $? -ne 0 ]; then
    echo "An error has occurred initializing the terraform modules"
    exit 1
fi

echo "yes" | terraform apply -auto-approve
if [ $? -ne 0 ]; then
    echo "An error has occurred running terraform apply on the new kubernetes deployment"
    exit 1
fi

if [ "$skipShutdown" == "false" ]; then
    echo ""
    echo "deallocating jumpbox.."
    az vm deallocate -g $resourceGroup -n jump
    if [ $? -ne 0 ]; then
        echo "An error has occurred deallocating jumpbox"
        exit 1
    fi
fi

exit 0