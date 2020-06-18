#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 2 ]; then
  echo "usage: ice-single.sh  <ice|deice> resource-group-name"
  exit 1
fi

if [[ $1 == "ice" ]]; then
  endState="VM deallocated"
  command=deallocate
elif [[ $1 == "deice" ]]; then
  endState="VM running"
  command=start
else
  echo "usage: ice-single.sh  <ice|deice> resource-group-name"
  exit 1
fi

rg=$2
source $SCRIPT_DIR/login-azure.sh

rgStatus=$(az group exists -n $rg)
if [[ "$rgStatus" != "true" ]]; then
  echo "Resource group $rg does not exist"
  exit 1
fi

status=$(az vm show -g $rg -n nuke -d | jq -r '.powerState')
if [[ "$status" != "$endState" ]]; then
  echo "${command}-ing server nuke"
  az vm ${command} -g $rg -n nuke
  status=$(az vm show -g $rg -n nuke -d | jq -r '.powerState')
  echo "Server nuke state is \"${status}\""
elif [[ -z "$status" ]]; then
  echo "Server nuke does not exist in resource group $rg"
else
  echo "Server nuke state is \"${status}\""
fi

az logout
