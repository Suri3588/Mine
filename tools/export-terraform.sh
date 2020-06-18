#!/usr/bin/env bash

while [ -n "$1" ]; do
	case "$1" in
        "--copy-only")
            copyOnly=true
            shift
            ;;
        *)
            echo "Error: Unknown command: $1"
            exit 1
	esac
done

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

if [ -z "$subscriptionId" ]; then
    echo "No subscription ID specified in secret-vars.txt"
    exit 1
fi

if [ -z "$terraformDir" ]; then
    echo "No Terraform directory specified in secret-vars.txt"
    exit 1
fi

# replace the py-az2tf azure.tf with the pinned version
cp $scriptDir/templates/azure.tf /home/vagrant/py-az2tf/stub

# reverse existing Azure deployment into terraform scripts
pushd /home/vagrant/py-az2tf > /dev/null

if [ "$copyOnly" != "true" ]; then
    rm -rf generated
    ./az2tf.sh -s $subscriptionId -g $resourceGroup 
    if [ $? -ne 0 ]; then
        echo "An error has occurred reversing the existing azure environment"
        exit 1
    fi
fi

# copy the reversed terraform files to the terraform deployment directory
rsync -a /home/vagrant/py-az2tf/generated/$(ls "generated" | grep "tf.")/ $deploymentDir/$terraformDir --exclude=*.sh
popd > /dev/null

# add ignore_changes to image_url
grep -l "resource azurerm_virtual_machine " $deploymentDir/$terraformDir/*.tf > $scriptDir/temp/exportFixList.txt

while read file; do
    nameLine=$(grep " name " $file | head -1)
    ignoreLine="  lifecycle {\\n    ignore_changes = [ storage_os_disk[0].image_uri ]\\n  }\\n$nameLine"
    sed -i "s/$nameLine/$ignoreLine/g" $file
done < $scriptDir/temp/exportFixList.txt 

# add ignore_changes to storage_permissions
grep -l "resource azurerm_key_vault " $deploymentDir/$terraformDir/*.tf > $scriptDir/temp/exportFixList.txt

while read file; do
    nameLine=$(grep " name " $file | head -1)
    ignoreLine="  lifecycle {\\n    ignore_changes = [ access_policy[0].storage_permissions ]\\n  }\\n$nameLine"
    sed -i "s/$nameLine/$ignoreLine/g" $file
done < $scriptDir/temp/exportFixList.txt 

# fix deprecated fields
find $deploymentDir/$terraformDir -name "*__BGInfo.tf" > $scriptDir/temp/exportFixList.txt 
find $deploymentDir/$terraformDir -name "*__AzureDiskEncryptionForLinux.tf" >> $scriptDir/temp/exportFixList.txt 
find $deploymentDir/$terraformDir -name "*__cse-configure-ansible-remoting-ps1.tf" >> $scriptDir/temp/exportFixList.txt 
find $deploymentDir/$terraformDir -name "*__OmsAgentForLinux.tf" >> $scriptDir/temp/exportFixList.txt
find $deploymentDir/$terraformDir -name "*__IaaSAntimalware.tf" >> $scriptDir/temp/exportFixList.txt
find $deploymentDir/$terraformDir -name "*__MicrosoftMonitoringAgent.tf" >> $scriptDir/temp/exportFixList.txt
find $deploymentDir/$terraformDir -name "*__AzureNetworkWatcherExtension.tf" >> $scriptDir/temp/exportFixList.txt
find $deploymentDir/$terraformDir -name "*__DependencyAgentLinux.tf" >> $scriptDir/temp/exportFixList.txt

while read file; do
    locLine=$(grep "location" $file)
    rsgLine=$(grep "resource_group_name" $file)
    vmnLine=$(grep "virtual_machine_name" $file)
    vmName=$(echo $vmnLine | awk '{print $3}' | tr -d '"')
    rsgLower=$(echo $resourceGroup | tr '[:upper:]' '[:lower:]')
    vmId="/subscriptions/$subscriptionId/resourceGroups/$rsgLower/providers/Microsoft.Compute/virtualMachines/$vmName"
    sed -i "/$locLine/d" $file
    sed -i "/$rsgLine/d" $file
    sed -i "s#$vmnLine#  virtual_machine_id         = \"$vmId\"#g" $file
done < $scriptDir/temp/exportFixList.txt 

exit 0
