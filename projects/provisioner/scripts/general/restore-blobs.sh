#!/bin/bash
studySnapshotSA=$1
studySA=$2

echo "Getting study accounts info"
studySnapKeys=($(az storage account keys list -n $studySnapshotSA -g $rg | jq -r '.[].value'))
snapInfo=$(az storage account show -n $studySnapshotSA -g $rg)
srcBlob=$(echo "$snapInfo" | jq -r '.primaryEndpoints.blob')
snapTime=$(echo "$snapInfo" | jq -r '.creationTime')
snapTime=${snapTime%.*}Z
studyKeys=($(az storage account keys list -n $studySA -g $rg | jq -r '.[].value'))
destBlob=$(az storage account show -n $studySA -g $rg | jq -r '.primaryEndpoints.blob')

echo "Deleting modified containers"
containerNames=($(az storage container list --account-name $studySA --account-key ${studyKeys[0]} | jq -r '.[].name'))
for containerName in "${containerNames[@]}"; do
  echo "az storage container delete --name ${containerName} --account-name $studySA --account-key ${studyKeys[0]} --if-modified-since $snapTime"
  result=$(az storage container delete --name ${containerName} --account-name $studySA --account-key ${studyKeys[0]} --if-modified-since $snapTime)
  if [[ ! -z $result ]]; then
    status=$(echo $result | jq -r '.deleted')
    if [[ "$status" == "true" ]]; then
      echo "$containerName" >> /tmp/deletedContainers.tmp
    fi
  fi
done

echo "Copying study blobs to snapshot storage"
counter=0
containerNames=($(az storage container list --account-name $studySnapshotSA --account-key ${studySnapKeys[0]} | jq -r '.[].name'))

if [[ -e /tmp/deletedContainers.tmp ]]; then
  echo "Re-creating missing containers"
  echo "${containerNames[@]}" >> /tmp/containers.tmp
  sort -o /tmp/containers.lst /tmp/containers.tmp
  sort -o /tmp/deletedContainers.lst /tmp/deletedContainers.tmp
  deletedContainers=($(comm -1 -2 /tmp/containers.lst /tmp/deletedContainers.lst))
  for containerName in "${deletedContainers[@]}"; do
    az storage container create -n $containerName --account-name $studySA --account-key ${studyKeys[0]}
  done
  rm /tmp/containers.*
  rm /tmp/deletedContainers.*
fi

for containerName in "${containerNames[@]}"; do
  mkdir -p ~/journals/${containerName}
  echo "azcopy --source ${srcBlob}${containerName}/ --destination ${destBlob}${containerName}/ --source-key ${studySnapKeys[0]} --dest-key ${studyKeys[0]} --exclude-older --exclude-newer --sync-copy --recursive"
  azcopy --source ${srcBlob}${containerName}/ \
      --destination ${destBlob}${containerName}/ \
      --source-key ${studySnapKeys[0]} --dest-key ${studyKeys[0]} \
      --exclude-older --exclude-newer --recursive \
      --resume ~/journals/${containerName} &
  ((counter++))
  if [ $counter -eq 32 ]; then
    wait
    rm -rf ~/journals/*
    counter=0
  fi
done
wait
rm -rf ~/journals/*
