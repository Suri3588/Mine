#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 1 ]; then
  echo "usage: backup-blobs.sh resource-group-name"
  exit 1
fi

beginTime=$(date)

source $SCRIPT_DIR/login-azure.sh

srcRg=$1
rgStatus=$(az group exists -n $srcRg)
if [[ "$rgStatus" != "true" ]]; then
  echo "Resource group $srcRg does not exist"
  exit 1
fi

echo "Finding storage accounts"
saArray=( $(az storage account list -g $srcRg | jq -r '.[].name') )
srcStudySA="UNKNOWN"
destStudySA="UNKNOWN"
for sa in "${saArray[@]}"; do
  if [[ "$sa" == *sback ]]; then
    destStudySA=$sa
    destStudySAKeys=($(az storage account keys list -n $sa -g $srcRg | jq -r '.[].value'))
  elif [[ "$sa" == *study ]]; then
    srcStudySA=$sa
    srcStudySAKeys=($(az storage account keys list -n $sa -g $srcRg | jq -r '.[].value'))
  fi
done
if [[ $srcStudySA == "UNKNOWN" ]]; then
  echo "Study SA does not exist in source"
  exit 1
fi
if [[ $destStudySA == "UNKNOWN" ]]; then
  destStudySA="${srcStudySA/study/sback}"
  location=$(az storage account show -n $srcStudySA -g $srcRg | jq -r '.primaryLocation')
  echo "Creating study backup storage account ($destStudySA) in $location"
  az storage account create -g $srcRg -n $destStudySA --location $location --sku Standard_LRS
  destStudySAKeys=($(az storage account keys list -n $destStudySA -g $srcRg | jq -r '.[].value'))
fi

$SCRIPT_DIR/ice-system.sh ice $srcRg
$SCRIPT_DIR/login-azure.sh

startTime=$(date)

echo "Deleting destination study containers"
containerNames=($(az storage container list --account-name $destStudySA --account-key ${destStudySAKeys[0]} | jq -r '.[].name'))
for containerName in "${containerNames[@]}"; do
  az storage blob delete-batch --source $containerName --account-name $destStudySA --account-key ${destStudySAKeys[0]} --delete-snapshots include
done

echo "Backing up study containers"
srcStudySAInfo=$(az storage account show -n $srcStudySA -g $srcRg)
srcBlob=$(echo "$srcStudySAInfo" | jq -r '.primaryEndpoints.blob')
destBlob=$(az storage account show -n $destStudySA -g $srcRg | jq -r '.primaryEndpoints.blob')
containerNames=($(az storage container list --account-name $srcStudySA --account-key ${srcStudySAKeys[0]} | jq -r '.[].name'))
echo "" > ~/sourceHashes.txt
echo "" > ~/containers.txt
counter=0
for containerName in "${containerNames[@]}"; do
  az storage blob list --container-name $containerName --account-key ${srcStudySAKeys[0]} --account-name $srcStudySA | jq -r '.[] | .name + "  " + .properties.contentSettings.contentMd5' >> ~/sourceHashes.txt
  mkdir -p ~/journals/${containerName}
  az storage container create -n $containerName --account-key ${destStudySAKeys[0]} --account-name $destStudySA
  azcopy --source ${srcBlob}${containerName}/ --source-key ${srcStudySAKeys[0]} \
      --destination ${destBlob}${containerName}/ --dest-key ${destStudySAKeys[0]} \
      --recursive --sync-copy --resume ~/journals/${containerName} &
  ((counter++))
  if [ $counter -eq 16 ]; then
    wait
    rm -rf ~/journals/*
    counter=0
    echo "Batch done $(date)"
  fi
done
wait
rm -rf ~/journals/*

echo "" > ~/destHashes.txt
for containerName in "${containerNames[@]}"; do
  az storage blob list --container-name $containerName --account-key ${destStudySAKeys[0]} --account-name $destStudySA | jq -r '.[] | .name + "  " + .properties.contentSettings.contentMd5' >> ~/destHashes.txt
done

stopTime=$(date)

$SCRIPT_DIR/ice-system.sh deice $srcRg
$SCRIPT_DIR/ice-ancillary.sh deice $srcRg

echo "Began: ${beginTime}    Complete: $(date)"
echo "Start: ${startTime}    Stop: ${stopTime}"
