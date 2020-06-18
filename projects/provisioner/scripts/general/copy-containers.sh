#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 4 ]; then
  echo "usage: copy-containers.sh resource-group-name src-study-account dest-study-account copy-file"
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
srcStudySA=$2
destStudySA=$3
copyFile=$4
srcStudySAKeys=($(az storage account keys list -n $srcStudySA -g $srcRg | jq -r '.[].value'))
srcBlob=$(az storage account show -n $srcStudySA -g $srcRg | jq -r '.primaryEndpoints.blob')
destStudySAKeys=($(az storage account keys list -n $destStudySA -g $srcRg | jq -r '.[].value'))
destBlob=$(az storage account show -n $destStudySA -g $srcRg | jq -r '.primaryEndpoints.blob')

echo "Copying containers"
counter=0
echo " " > ~/containerSourceHashes.txt
while read -r containerName; do
  echo "Copying container $containerName"
  az storage blob list --container-name $containerName --account-key ${srcStudySAKeys[0]} --account-name $srcStudySA | jq -r '.[] | .name + "  " + .properties.contentSettings.contentMd5' >> ~/containerSourceHashes.txt
  mkdir -p ~/journals/${containerName}
  az storage container create -n $containerName --account-key ${destStudySAKeys[0]} --account-name $destStudySA
  azcopy --source ${srcBlob}${containerName}/ --source-key ${srcStudySAKeys[0]} \
      --destination ${destBlob}${containerName}/ --dest-key ${destStudySAKeys[0]} \
      --recursive --resume ~/journals/${containerName} &
  ((counter++))
  if [ $counter -eq 16 ]; then
    wait
    rm -rf ~/journals/*
    counter=0
    echo "Batch done $(date)"
  fi
done < $copyFile
wait
rm -rf ~/journals/*

echo " " > ~/containerDestHashes.txt
while read containerName; do
  az storage blob list --container-name $containerName --account-key ${destStudySAKeys[0]} --account-name $destStudySA | jq -r '.[] | .name + "  " + .properties.contentSettings.contentMd5' >> ~/containerDestHashes.txt
done < $copyFile

