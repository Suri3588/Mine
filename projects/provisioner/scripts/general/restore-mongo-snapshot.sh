#!/bin/bash
find_acct () {
  saType=$1
  tempSA="UNKNOWN"
  for sa in "${saArray[@]}"; do
    if [[ "$sa" == *$saType ]]; then
      tempSA=$sa
    fi
  done
}

find_mongo_acct () {
  find_acct mongo
  mongoSA=$tempSA
}

find_snapshot_acct () {
  find_acct msnap
  snapshotSA=$tempSA
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

start_mongoServers () {
  mod_server start mongo
}

stop_mongoServers () {
  mod_server stop mongo
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 1 ]; then
  echo "usage: restore-mongo-snapshot.sh resource-group-name"
  exit 1
fi

rg=$1
source $SCRIPT_DIR/login-azure.sh
echo "START: $(date)"

vmArray=( $(az vm list -g $rg | jq -r '.[].name') )
saArray=( $(az storage account list -g $rg | jq -r '.[].name') )

find_mongo_acct
if [[ $mongoSA == "UNKNOWN" ]]; then
  echo "Mongo SA does not exit"
  exit 1
fi
echo "Found mongo account $mongoSA"

find_snapshot_acct
if [[ $snapshotSA == "UNKNOWN" ]]; then
  echo "Mongo Snapshot SA does not exit"
  exit 1
fi
echo "Found snapshot account $snapshotSA"

echo "STOPPING: $(date)"
stop_mongoServers
echo "STOPPED: $(date)"

mongoInfo=$(az storage account show -n $mongoSA -g $rg)
location=$(echo $mongoInfo | jq -r '.primaryLocation')

snapInfo=$(az storage account show -n $snapshotSA -g $rg)
snapLocation=$(echo $snapInfo | jq -r '.primaryLocation')

echo "Creating mongo persistent-storage container"
snapKeys=($(az storage account keys list -n $snapshotSA -g $rg | jq -r '.[].value'))

echo "Detaching Mongo data disks $(date)"
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

mongoKeys=($(az storage account keys list -n $mongoSA -g $rg | jq -r '.[].value'))

echo "Deleting mongo disks"
for vm in "${vmArray[@]}"
do
  if [[ $vm == mongo* ]]; then
    mongoDisk=$(az vm unmanaged-disk list -g $rg -n $vm)
    diskName=$(echo $mongoDisk | jq -r '.[].name')
    az storage blob delete --c persistent-storage --n $diskName --account-name $mongoSA --account-key ${mongoKeys[0]}
  fi
done
wait

echo "Copying over mongo vhds $(date)"
destBlob=$(echo $mongoInfo | jq -r '.primaryEndpoints.blob')
srcBlob=$(az storage account show -n $snapshotSA -g $rg | jq -r '.primaryEndpoints.blob')

azcopy --source ${srcBlob}persistent-storage/ \
    --destination ${destBlob}persistent-storage/ \
    --source-key ${snapKeys[0]} --dest-key ${mongoKeys[0]} \
    --recursive

echo "Re-attaching Mongo data disks $(date)"
indice=0
while [ $indice -lt $numMongoVms ]; do
  vm=${mongoVms[$indice]}
  disk=${mongoDisks[$indice]}
  vhdUri=$(echo $disk | jq -r '.[].vhd.uri')
  diskName=$(echo $disk | jq -r '.[].name')
  lun=$(echo $disk | jq -r '.[].lun')
  az vm unmanaged-disk attach -g $rg --vm-name $vm --vhd-uri $vhdUri \
    --lun $lun --name $diskName &
  let indice=indice+1
done
wait

az logout
