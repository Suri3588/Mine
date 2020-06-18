#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 3 ]; then
  echo "usage: delete-containers.sh resource-group-name study-account delete-file"
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
deleteFile=$3
srcStudySAKeys=($(az storage account keys list -n $srcStudySA -g $srcRg | jq -r '.[].value'))

echo "Deleting containers"
while read -r containerName; do
  echo "Delete container $containerName"
  az storage container delete -n $containerName --account-name $srcStudySA --account-key ${srcStudySAKeys[0]}
done < $deleteFile

