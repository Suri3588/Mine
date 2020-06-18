#!/bin/bash
login=$1
key=$2
xvars=$3

if [ ! -f "$key" ]; then
  echo "Could not find file: $key"
  exit 1
fi

if [ ! -f "$xvars" ]; then
  echo "Could not find secrets file: $xvars"
  exit 1
fi

echo "Sleeping for 15 seconds"
sleep 15

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

jumpip=$(az network public-ip show --resource-group $resourceGroup --name jump-public-ip --query "{address: ipAddress}" 2>/dev/null | jq -r .address )
if [ -z "$jumpip" ]; then
    echo "No IP address found for jump-public-ip in $resourceGroup"
    exit 1
fi

pushd $scriptDir > /dev/null
echo "Provisioning jumpbox"
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u $login --private-key $key -i "$jumpip," playbook.yml --extra-vars "@$xvars"
if [ $? -ne 0 ]; then
    echo "An error occurred running the jumpbox Ansible playbook"
    exit 1
fi
popd > /dev/null
