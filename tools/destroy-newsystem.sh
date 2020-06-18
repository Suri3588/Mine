#!/usr/bin/env bash

while [ -n "$1" ]; do
	case "$1" in
        "--skip-ip")
            skipIp=true
            shift
            ;;
        "--skip-remote-state")
            skipRemoteState=true
            shift
            ;;
        "--skip-dns")
            skipDns=true
            shift
            ;;
        *)
            echo "Error: Unknown command: $1"
            exit 1
	esac
done

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

if [ -z "$terraformDir" ]; then
    echo "No Terraform directory specified in secret-vars.txt"
    exit
fi

if [ -z "$terraformStorageAccount" ]; then
    echo "No terraformStorageAccount environment variable specified in secret-vars.txt"
    exit
fi

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
pushd $deploymentDir/$terraformDir > /dev/null

terraform init
if [ $? -ne 0 ]; then
    echo "An error has occurred initializing the terraform modules"
    exit
fi

if [ "$skipIp" == "true" ]; then
    echo "Skipping the public IP in destruction"
else
    staticIpArgs="-target module.publicIp"
fi

terraform destroy -target module.resgroup -target module.kubegroup -target module.jumpbox -target module.passthru -target module.nginx -target azurerm_storage_account.passthru_jumpbox_boot -target random_id.passthru_jumpbox_boot_prefix $staticIpArgs
if [ $? -ne 0 ]; then
    echo "An error occurred destroying the new system"
    exit
fi

popd > /dev/null
pushd $scriptDir > /dev/null

if [ "$isSharedService" == "true" ]; then
    ./upload-app-insights.sh --delete
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

if [ "$skipRemoteState" == "true" ]; then
    echo "Skipping the remote Terraform state deletion"
else
    exists=$(az storage blob exists --account-name $terraformStorageAccount --container-name tfstate --name $resourceGroup 2> /dev/null | jq -r .exists)
    if [ "$exists" == "true" ]; then
        echo "Deleting the remote Terraform state for $resourceGroup from $terraformStorageAccount"
        az storage blob delete --account-name $terraformStorageAccount --container-name tfstate --name $resourceGroup 2> /dev/null
    else
        echo "Remote Terraform state for $resourceGroup from $terraformStorageAccount does not exist"
    fi
fi

if [ "$skipDns" != "true" ]; then
    ./update-dns.sh oldsystem
fi
