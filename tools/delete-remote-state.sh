#!/usr/bin/env bash

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

if [ -z "$terraformStorageAccount" ]; then
    echo "No terraformStorageAccount environment variable specified in secret-vars.txt"
    exit
fi

echo ""
echo -e "\033[1mAre you sure you want to delete the remote terraform state for $resourceGroup (\033[0myes|\033[1mno)?\033[0m"

read answer
if [ "${answer,,}" != "yes" ]; then
        exit 0
fi

exists=$(az storage blob exists --account-name $terraformStorageAccount --container-name tfstate --name $resourceGroup | jq -r .exists)
if [ "$exists" == "true" ]; then
    echo "Deleting the remote Terraform state for $resourceGroup from $terraformStorageAccount"
    az storage blob delete --account-name $terraformStorageAccount --container-name tfstate --name $resourceGroup
else
    echo "Remote Terraform state for $resourceGroup from $terraformStorageAccount does not exist"
fi
