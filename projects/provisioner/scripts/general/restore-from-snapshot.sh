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
  find_acct snap
  snapshotSA=$tempSA
}

find_study_acct () {
  find_acct study
  studySA=$tempSA
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
  echo "usage: do-restore.sh  resource-group-name snapshot-id"
  exit 1
fi

rg=$1
source $SCRIPT_DIR/login-azure.sh
echo "START: $(date)"

vmArray=( $(az vm list -g $rg | jq -r '.[].name') )
saArray=( $(az storage account list -g $rg | jq -r '.[].name') )

find_snapshot_acct
if [[ $snapshotSA != "UNKNOWN" ]]; then
  echo "Snapshot ($snapshotSA) already exists"
  exit 1
fi

find_mongo_acct
if [[ $mongoSA == "UNKNOWN" ]]; then
  echo "Mongo SA does not exit"
  exit 1
fi
echo "Found mongo account $mongoSA"

find_study_acct
if [[ $studySA == "UNKNOWN" ]]; then
  echo "Study SA does not exit"
  exit 1
fi
echo "Found study account $studySA"

echo "STOPPING: $(date)"
stop_appServers
stop_mongoServers
echo "STOPPED: $(date)"

mongoInfo=$(az storage account show -n $mongoSA -g $rg)
location=$(echo $mongoInfo | jq -r '.primaryLocation')

mongoSnapSA="${mongoSA/mongo/msnap}"
echo "Creating mongo snapshot storage account ($mongoSnapSA) in $location"
az storage account create -g $rg -n $mongoSnapSA --location $location --sku Standard_LRS

echo "Creating mongo persistent-storage container"
mongoSnapKeys=($(az storage account keys list -n $mongoSnapSA -g $rg | jq -r '.[].value'))
az storage container create -n persistent-storage --account-key ${mongoSnapKeys[0]} --account-name $mongoSnapSA

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

echo "Copying over mongo vhds $(date)"
mongoKeys=($(az storage account keys list -n $mongoSA -g $rg | jq -r '.[].value'))
srcBlob=$(echo $mongoInfo | jq -r '.primaryEndpoints.blob')
destBlob=$(az storage account show -n $mongoSnapSA -g $rg | jq -r '.primaryEndpoints.blob')

azcopy --source ${srcBlob}persistent-storage/ \
    --destination ${destBlob}persistent-storage/ \
    --source-key ${mongoKeys[0]} --dest-key ${mongoSnapKeys[0]} \
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
    --vhd-uri $vhdUri --lun $lun --name $diskName &
  let indice=indice+1
done
wait

studySnapSA="${studySA/study/ssnap}"
echo "Creating study snapshot storage account ($studySnapSA) in $location $(date)"
az storage account create -g $rg -n $studySnapSA --location $location --sku Standard_LRS

studySnapKeys=($(az storage account keys list -n $studySnapSA -g $rg | jq -r '.[].value'))
studyKeys=($(az storage account keys list -n $studySA -g $rg | jq -r '.[].value'))
srcBlob=$(az storage account show -n $studySA -g $rg | jq -r '.primaryEndpoints.blob')
destBlob=$(az storage account show -n $studySnapSA -g $rg | jq -r '.primaryEndpoints.blob')

echo "Copying study blobs to snapshot storage $(date)"
containerNames=($(az storage container list --account-name $studySA --account-key ${studyKeys[0]} | jq -r '.[].name'))
counter=0
for containerName in "${containerNames[@]}"; do
  az storage container create -n $containerName --account-key ${studySnapKeys[0]} --account-name $studySnapSA
  mkdir -p ~/journals/${containerName}
  azcopy --source ${srcBlob}${containerName}/ \
      --destination ${destBlob}${containerName}/ \
      --source-key ${studyKeys[0]} --dest-key ${studySnapKeys[0]} \
      --recursive --resume ~/journals/${containerName} &
  ((counter++))
  if [ $counter -eq 32 ]; then
    wait
    rm -rf ~/journals/*
    counter=0
  fi
done
wait
rm -rf ~/journals/*

echo "STARTING $(date)"
start_mongoServers
start_appServers
echo "STARTED $(date)"

az logout
