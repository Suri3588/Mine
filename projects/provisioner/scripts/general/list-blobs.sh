#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -lt 3 -o $# -gt 4 ]; then
  echo "usage: list-blobs.sh resource-group-name study-account [list-file] dump-file"
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
srcStudySAKeys=($(az storage account keys list -n $srcStudySA -g $srcRg | jq -r '.[].value'))
echo "Listing study blobs"
if [ $# -eq 3 ]; then
  dumpFile=$3
  containerNames=($(az storage container list --account-name $srcStudySA --account-key ${srcStudySAKeys[0]} | jq -r '.[].name'))
else
  listFile=$3
  dumpFile=$4
  declare -a containerNames
  while read -r containerName; do
    containerNames=("${containerNames[@]}" "$containerName")
  done < $listFile
fi

counter=0
echo "" > $dumpFile
for containerName in "${containerNames[@]}"; do
  echo "Working $containerName"
  blobsStuff=($(az storage blob list --container-name $containerName --account-key ${srcStudySAKeys[0]} --account-name $srcStudySA | jq -r '.[] | .name + "  " + .properties.contentSettings.contentMd5'))
  count=0
  for blobStuff in "${blobsStuff[@]}"; do
    if [ $count -eq 0 ]; then
      dumpStr="$containerName $blobStuff"
      count=1
    else
      echo $dumpStr $blobStuff >> $dumpFile
      count=0
    fi
  done
done

