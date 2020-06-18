#!/bin/bash
find_accts () {
  mongoSA="UNKNOWN"
  studySA="UNKNOWN"
  mongoSnapSA="UNKNOWN"
  studySnapSA="UNKNOWN"
  for sa in "${saArray[@]}"; do
    if [[ "$sa" == *mongo ]]; then
      mongoSA=$sa
    elif [[ "$sa" == *study ]]; then
      studySA=$sa
    elif [[ "$sa" == *msnap ]]; then
      mongoSnapSA=$sa
    elif [[ "$sa" == *ssnap ]]; then
      studySnapSA=$sa
    fi
  done
  if [[ $mongoSA == "UNKNOWN" ]]; then
    echo "Mongo SA does not exist"
    exit 1
  fi
  echo "Found mongo account $mongoSA"

  if [[ $studySA == "UNKNOWN" ]]; then
    echo "Study SA does not exist"
    exit 1
  fi
  echo "Found study account $studySA"

  if [[ $mongoSnapSA == "UNKNOWN" ]]; then
    echo "Mongo Snapshot SA does not exist"
    exit 1
  fi
  echo "Found mongo snapshot account $mongoSnapSA"

  if [[ $studySnapSA == "UNKNOWN" ]]; then
    echo "Study Snapshot SA does not exist"
    exit 1
  fi
  echo "Found study snapshot account $studySnapSA"
}

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
  mod_server stop app
}

stop_mongoServers () {
  mod_server stop mongo
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 1 ]; then
  echo "usage: use-snapshot.sh  resource-group-name"
  exit 1
fi

rg=$1
source $SCRIPT_DIR/login-azure.sh

vmArray=( $(az vm list -g $rg | jq -r '.[].name') )
saArray=( $(az storage account list -g $rg | jq -r '.[].name') )

find_accts

stop_appServers
stop_mongoServers

mongoInfo=$(az storage account show -n $mongoSA -g $rg)
location=$(echo $mongoInfo | jq -r '.primaryLocation')

echo "Detaching Mongo data disks"
numMongoVms=0
mongoVms=()
mongoDisks=()

for vm in "${vmArray[@]}"
do
  if [[ $vm == mongo* ]]; then
    mongoVms+=($vm)
    mongoDisk=$(az vm unmanaged-disk list -g $rg -n $vm)
    mongoDisks+=("$mongoDisk")
    let numMongoVms=numMongoVms+1
    diskName=$(echo $mongoDisk | jq -r '.[].name')
    az vm unmanaged-disk detach -g $rg --vm-name $vm -n $diskName &
  fi
done
wait

echo "Deleting mongo vhds"
mongoKeys=($(az storage account keys list -n $mongoSA -g $rg | jq -r '.[].value'))
az storage blob delete-batch --source persistent-storage --delete-snapshots include \
    --account-name $mongoSA --account-key ${mongoKeys[0]} \
#   --dryrun

echo "Copying in snapshot mongo vhds"
mongoSnapKeys=($(az storage account keys list -n $mongoSnapSA -g $rg | jq -r '.[].value'))
srcBlob=$(az storage account show -n $mongoSnapSA -g $rg | jq -r '.primaryEndpoints.blob')
destBlob=$(echo $mongoInfo | jq -r '.primaryEndpoints.blob')

echo "azcopy --source ${srcBlob}persistent-storage/ --destination ${destBlob}persistent-storage/ --source-key ${mongoSnapKeys[0]} --dest-key ${mongoKeys[0]} --sync-copy --recursive"

azcopy --source ${srcBlob}persistent-storage/ \
    --destination ${destBlob}persistent-storage/ \
    --source-key ${mongoSnapKeys[0]} --dest-key ${mongoKeys[0]} \
    --recursive

echo "Re-attaching Mongo data disks"
indice=0
while [ $indice -lt $numMongoVms ]; do
  vm=${mongoVms[$indice]}
  disk=${mongoDisks[$indice]}
  vhdUri=$(echo $disk | jq -r '.[].vhd.uri')
  diskName=$(echo $disk | jq -r '.[].name')
  lun=$(echo $disk | jq -r '.[].lun')
  az vm unmanaged-disk attach -g $rg --vm-name $vm --vhd-uri $vhdUri \
    --vhd-uri $vhdUri --lun $lun --name $diskName &
  let indice=indice+1
done
wait

source $SCRIPT_DIR/restore-blobs.sh $studySnapSA $studySA

start_mongoServers
start_appServers

az logout
