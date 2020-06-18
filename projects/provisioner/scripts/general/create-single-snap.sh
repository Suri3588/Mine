#!/bin/bash
find_acct () {
  saType=$1
  tempSA="UNKNOWN"
  for sa in "${saArray[@]}"; do
    if [[ "$sa" == "$saType"* ]]; then
      tempSA=$sa
    fi
  done
}

find_snapshot_acct () {
  find_acct ssnap
  snapshotSA=$tempSA
}

find_study_acct () {
  find_acct study
  studySA=$tempSA
}

mod_server () {
  command=$1
  az vm $command -g $rg -n nuke
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 1 ]; then
  echo "usage: create-single-snap.sh  resource-group-name"
  exit 1
fi

rg=$1
source $SCRIPT_DIR/login-azure.sh
rgStatus=$(az group exists -n $rg)
if [[ "$rgStatus" != "true" ]]; then
  echo "Resource group $rg does not exist"
  exit 1
fi

saArray=( $(az storage account list -g $rg | jq -r '.[].name') )

find_snapshot_acct
if [[ $snapshotSA != "UNKNOWN" ]]; then
  echo "Snapshot ($snapshotSA) already exists"
  exit 1
fi

find_study_acct
if [[ $studySA == "UNKNOWN" ]]; then
  echo "Study SA does not exit"
  exit 1
fi
echo "Found study account ($studySA)"

diskNames=( $(az disk list -g $rg | jq -r '.[].name') )
for diskName in "${diskNames[@]}"; do
  if [[ "$diskName" == "nuke-snap-disk" ]]; then
    echo "Snapshot disk ${diskName} already exists"
    exit 1
  fi
done

echo "Stopping nuke vm"
az vm stop -g $rg -n nuke

if [ $? -ne 0 ]; then
  echo 'VM name nuke was not found'
  exit 1
fi

# Copy disks
echo "Copying nuke-data-disk"
az disk create -g $rg -n nuke-snap-disk --source nuke-data-disk

studyInfo=$(az storage account show -n $studySA -g $rg)
location=$(echo $studyInfo | jq -r '.primaryLocation')

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

az vm start -g $rg -n nuke

az logout
