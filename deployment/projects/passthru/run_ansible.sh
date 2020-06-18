#!/bin/bash
login=$1
key=$2
xvars=$3
local_xvars=$4

if [ ! -f "$key" ]; then
  echo "Could not find file: $key"
  exit 1
fi

if [ ! -f "$xvars" ]; then
  echo "Could not find secrets file: $xvars"
  exit 1
fi

if [ ! -f "$local_xvars" ]; then
  echo "Could not find secrets file: $local_xvars"
  exit 1
fi

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

pushd $scriptDir > /dev/null
echo "Creating Provisioning Set-Up..."
ansible-playbook -i localhost, playbook.yml --extra-vars "@$local_xvars"
if [ $? -ne 0 ]; then
    echo "An error occurred running the passthru-local Ansible playbook"
    exit 1
fi
popd > /dev/null

pushd $scriptDir/passthru > /dev/null
echo "Provisioning NGINX..."
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u $login --private-key $key -i localhost,  waitForBoxen.yml
if [ $? -ne 0 ]; then
    echo "An error occurred running the passthru localhost Ansible playbook"
    exit 1
fi

ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u $login --private-key $key -i inventory -l passthru passthru.yml --extra-vars "@$xvars"
if [ $? -ne 0 ]; then
    echo "An error occurred running the passthru Ansible playbook"
    exit 1
fi
popd > /dev/null
