#!/bin/bash
modify_servers () {
  serverList=( "$@" )
  modServers=()

  if [[ ! -z "$serverList" ]]; then
    for server in "${serverList[@]}"; do
      status=$(az vm show -g $rg -n $server -d | jq -r '.powerState')
      if [[ "$status" != "$endState" ]]; then
        modServers+=("$server")
      elif [[ -z "$status" ]]; then
        echo "$server does not exist in resource group $rg"
      else
        echo "$server state is \"${status}\""
      fi
    done

    for server in "${modServers[@]}"; do
      echo "${command}-ing server ${server}"
      az vm $command -g $rg -n $server &
    done
    wait

    for server in "${modServers[@]}"; do
      status=$(az vm show -g $rg -n $server -d | jq -r '.powerState')
      echo "$server state is \"${status}\""
    done
  fi
}

find_servers () {
  appBase=$1
  serverArray=()
  for vm in "${vmArray[@]}"; do
    if [[ "$vm" == "$appBase" || "$vm" == "$appBase"[1-9] ]]; then
      serverArray+=("$vm")
    fi
  done
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 2 ]; then
  echo "usage: ice-system.sh  <ice|deice> resource-group-name"
  exit 1
fi

if [[ $1 == "ice" ]]; then
  endState="VM deallocated"
  command=deallocate
  vmTypes=(lb app mongo monitor)
elif [[ $1 == "deice" ]]; then
  endState="VM running"
  command=start
  vmTypes=(monitor mongo app lb)
else
  echo "usage: ice-system.sh  <ice|deice> resource-group-name"
  exit 1
fi

rg=$2
source $SCRIPT_DIR/login-azure.sh

rgStatus=$(az group exists -n $rg)
if [[ "$rgStatus" != "true" ]]; then
  echo "Resource group $rg does not exist"
  exit 1
fi

vmArray=( $(az vm list -g $rg | jq -r '.[].name') )

if [[ $1 == "ice" ]]; then
  serverArray=(appbuilder edgesvcblder elctrnbldr orch)
  modify_servers ${serverArray[@]}
fi

for vmType in "${vmTypes[@]}"; do
  echo "find_servers $vmType"
  find_servers $vmType
  echo "modify_servers ${serverArray[@]}"
  if [[ ! -z "$serverArray" ]]; then
    modify_servers ${serverArray[@]}
  else
    echo "No servers of type ${vmType} found"
  fi
done

az logout
