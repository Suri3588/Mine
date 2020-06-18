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
  echo "usage: restore-single-snap.sh  resource-group-name"
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
if [[ $snapshotSA == "UNKNOWN" ]]; then
  echo "Snapshot SA does not exist"
  exit 1
fi
echo "Found study snapshot account ($snapshotSA)"

find_study_acct
if [[ $studySA == "UNKNOWN" ]]; then
  echo "Study SA does not exit"
  exit 1
fi
echo "Found study account ($studySA)"

diskNames=( $(az disk list -g $rg | jq -r '.[].name') )
for diskName in "${diskNames[@]}"; do
  if [[ "$diskName" == "nuke-snap-disk" ]]; then
    foundDisk="$diskName"
  fi
done
if [[ -z "$foundDisk" ]]; then
  echo "No snapshot data disk found"
fi
echo "Found snapshot disk $foundDisk"

echo "Stopping nuke vm"
az vm stop -g $rg -n nuke

if [ $? -ne 0 ]; then
  echo 'VM name nuke was not found'
  exit 1
fi

# Detach the data disks
echo "Detaching disk"
az vm disk detach -g $rg -n nuke-data-disk --vm-name nuke

# Deleting disks
echo "Deleting data disk"
az disk delete -g $rg -n nuke-data-disk -y

# Copy disks
echo "Copying snapshot to data disk"
az disk create -g $rg -n nuke-data-disk --source nuke-snap-disk

# Attaching the data disks
echo "Attaching new disk"
az vm disk attach -g $rg --disk nuke-data-disk --vm-name nuke --lun 0

source $SCRIPT_DIR/restore-blobs.sh $snapshotSA $studySA

echo "Starting VM"
az vm start -g $rg -n nuke

az logout
