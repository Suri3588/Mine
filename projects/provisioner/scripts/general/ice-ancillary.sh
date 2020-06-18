#!/bin/bash

mod_server () {
  command=$1
  serverType=$2
  for vm in "${vmArray[@]}"; do
    if [[ $vm == ${serverType}* ]]; then
      echo "${command}-ing $vm..."
      az vm $command -g $rg -n $vm &
    fi
  done
  wait
}

start_appServers () {
  mod_server start app
}

start_mongoServers () {
  mod_server start mongo
}

stop_appServers () {
  mod_server deallocate app
}

stop_mongoServers () {
  mod_server deallocate mongo
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 2 ]; then
  echo "usage: ice-ancillary.sh  <ice|deice> resource-group-name"
  exit 1
fi

if [[ $1 == "ice" ]]; then
  endState="VM deallocated"
  command=deallocate
elif [[ $1 == "deice" ]]; then
  endState="VM running"
  command=start
else
  echo "usage: ice-ancillary.sh  <ice|deice> resource-group-name"
  exit 1
fi

rg=$2
source $SCRIPT_DIR/login-azure.sh
rgStatus=$(az group exists -n $rg)
if [[ "$rgStatus" != "true" ]]; then
  echo "Resource group $rg does not exist"
  az logout
  exit 1
fi

modServers=()

serverList=(appbuilder edgesvcblder elctrnbldr orch)
for server in "${serverList[@]}"; do
  status=$(az vm show -g $rg -n $server -d | jq -r '.powerState')
  if [[ "$status" != "$endState" ]]; then
    modServers+=("$server")
  else
    echo "$server state is \"${status}\""
  fi
done

for server in "${modServers[@]}"; do
  az vm $command -g $rg -n $server &
done
wait

for server in "${modServers[@]}"; do
  status=$(az vm show -g $rg -n $server -d | jq -r '.powerState')
  echo "$server state is \"${status}\""
done

az logout
