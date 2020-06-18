#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 1 ]; then
  echo "usage: blobs-howbig.sh resource-group-name"
  exit 1
fi

source $SCRIPT_DIR/login-azure.sh

srcRg=$1
rgStatus=$(az group exists -n $srcRg)
if [[ "$rgStatus" != "true" ]]; then
  echo "Resource group $srcRg does not exist"
  exit 1
fi
saArray=( $(az storage account list -g $srcRg | jq -r '.[].name') )
srcMongoSA="UNKNOWN"
srcMonitorSA="UNKNOWN"
srcStudySA="UNKNOWN"
for sa in "${saArray[@]}"; do
  if [[ "$sa" == *mongo ]]; then
    srcMongoSA=$sa
  elif [[ "$sa" == *monit ]]; then
    srcMonitorSA=$sa
  elif [[ "$sa" == *study ]]; then
    srcStudySA=$sa
  fi
done
if [[ $srcMongoSA == "UNKNOWN" ]]; then
  echo "Mongo SA does not exist in source"
  exit 1
fi
if [[ $srcMonitorSA == "UNKNOWN" ]]; then
  echo "Monitor SA does not exist in source"
  exit 1
fi
if [[ $srcStudySA == "UNKNOWN" ]]; then
  echo "Study SA does not exist in source"
  exit 1
fi
srcKeys=($(az storage account keys list -n $srcStudySA -g $srcRg | jq -r '.[].value'))

containerNames=($(az storage container list --account-name $srcStudySA --account-key ${srcKeys[0]} | jq -r '.[].name'))
totalBytes=0
containers=0
maxSize=0
maxContainer=""
for containerName in "${containerNames[@]}"; do
  bytes=$(az storage blob list --container-name $containerName --query "[*].[properties.contentLength]" --output tsv --account-name $srcStudySA --account-key ${srcKeys[0]}| paste --serial --delimiters=+ | bc)
  (( totalBytes += $bytes ))
  (( containers += 1 ))
  if [ $bytes -gt $maxSize ]; then
    maxSize=$bytes
    maxContainer=$containerName
  fi
done

echo "Containers: $containers"
echo "Total Bytes: $totalBytes"
echo "Largest ($maxSize) Container: $maxContainer"

az logout
