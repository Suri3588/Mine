#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -lt 2 -o $# -gt 3 ]; then
  echo "usage: migrate-system.sh src-resource-group-name dest-resource-group-name [backup]"
  exit 1
fi

beginTime=$(date)

source $SCRIPT_DIR/login-azure.sh

srcRg=$1
destRg=$2
rgStatus=$(az group exists -n $srcRg)
if [[ "$rgStatus" != "true" ]]; then
  echo "Resource group $srcRg does not exist"
  exit 1
fi
rgStatus=$(az group exists -n $destRg)
if [[ "$rgStatus" != "true" ]]; then
  echo "Resource group $destRg does not exist"
  exit 1
fi
if [ $# -eq 3 ] && [[ "$3" == "backup" ]]; then
  backup=true
else
  backup=false
fi

echo "Finding storage accounts"
saArray=( $(az storage account list -g $srcRg | jq -r '.[].name') )
srcMongoSA="UNKNOWN"
srcStudySA="UNKNOWN"
destStudySA="UNKNOWN"
for sa in "${saArray[@]}"; do
  if [[ "$sa" == *mongo ]]; then
    srcMongoSA=$sa
    srcMongoSAKeys=($(az storage account keys list -n $sa -g $srcRg | jq -r '.[].value'))
  elif [[ "$sa" == *sback ]]; then
    destStudySA=$sa
    destStudySAKeys=($(az storage account keys list -n $sa -g $srcRg | jq -r '.[].value'))
  elif [[ "$sa" == *study ]]; then
    srcStudySA=$sa
    srcStudySAKeys=($(az storage account keys list -n $sa -g $srcRg | jq -r '.[].value'))
  fi
done
if [[ $srcMongoSA == "UNKNOWN" ]]; then
  echo "Mongo SA does not exist in source"
  exit 1
fi
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

saArray=( $(az storage account list -g $destRg | jq -r '.[].name') )
destMongoSA="UNKNOWN"
for sa in "${saArray[@]}"; do
  if [[ "$sa" == *mongo ]]; then
    destMongoSA=$sa
    destMongoSAKeys=($(az storage account keys list -n $sa -g $destRg | jq -r '.[].value'))
  fi
done
if [[ $destMongoSA == "UNKNOWN" ]]; then
  echo "Mongo SA does not exist in destination"
  exit 1
fi

$SCRIPT_DIR/ice-system.sh ice $srcRg
$SCRIPT_DIR/ice-system.sh ice $destRg
$SCRIPT_DIR/login-azure.sh

startTime=$(date)
echo "Detaching Mongo data disks $(date)"
destNumMongoVms=0
destMongoVms=()
destMongoDisks=()

vmArray=( $(az vm list -g $destRg | jq -r '.[].name') )

for vm in "${vmArray[@]}"
do
  if [[ $vm == mongo* ]]; then
    destMongoVms+=($vm)
    mongoDisk=$(az vm unmanaged-disk list -g $destRg -n $vm)
    destMongoDisks+=("$mongoDisk")
    let destNumMongoVms=destNumMongoVms+1
    diskName=$(echo $mongoDisk | jq -r '.[].name')
    az vm unmanaged-disk detach -g $destRg --vm-name $vm -n $diskName &
  fi
done
wait

az storage blob delete-batch --source persistent-storage --account-name $destMongoSA --account-key ${destMongoSAKeys[0]} --delete-snapshots include

srcNumMongoVms=0
srcMongoVms=()
srcMongoDisks=()

vmArray=( $(az vm list -g $srcRg | jq -r '.[].name') )

for vm in "${vmArray[@]}"
do
  if [[ $vm == mongo* ]]; then
    srcMongoVms+=($vm)
    mongoDisk=$(az vm unmanaged-disk list -g $srcRg -n $vm)
    srcMongoDisks+=("$mongoDisk")
    let srcNumMongoVms=srcNumMongoVms+1
    diskName=$(echo $mongoDisk | jq -r '.[].name')
    az vm unmanaged-disk detach -g $srcRg --vm-name $vm -n $diskName &
  fi
done
wait

echo "Copying mongo vhd"
srcBlob=$(az storage account show -n $srcMongoSA -g $srcRg | jq -r '.primaryEndpoints.blob')
destBlob=$(az storage account show -n $destMongoSA -g $destRg | jq -r '.primaryEndpoints.blob')

azcopy --source ${srcBlob}persistent-storage/ \
    --destination ${destBlob}persistent-storage/ \
    --source-key ${srcMongoSAKeys[0]} --dest-key ${destMongoSAKeys[0]} \
    --recursive

echo "Reattaching mongo VHDs"
indice=0
while [ $indice -lt $srcNumMongoVms ]; do
  vm=${srcMongoVms[$indice]}
  disk=${srcMongoDisks[$indice]}
  vhdUri=$(echo $disk | jq -r '.[].vhd.uri')
  diskName=$(echo $disk | jq -r '.[].name')
  lun=$(echo $disk | jq -r '.[].lun')
  az vm unmanaged-disk attach -g $srcRg --vm-name $vm \
    --vhd-uri $vhdUri --lun $lun --name $diskName &
  let indice=indice+1
done
wait

indice=0
while [ $indice -lt $destNumMongoVms ]; do
  vm=${destMongoVms[$indice]}
  disk=${destMongoDisks[$indice]}
  vhdUri=$(echo $disk | jq -r '.[].vhd.uri')
  diskName=$(echo $disk | jq -r '.[].name')
  lun=$(echo $disk | jq -r '.[].lun')
  az vm unmanaged-disk attach -g $destRg --vm-name $vm \
    --vhd-uri $vhdUri --lun $lun --name $diskName &
  let indice=indice+1
done
wait

if [[ "$backup" == "true" ]]; then
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

  for containerName in "${containerNames[@]}"; do
    az storage blob list --container-name $containerName --account-key ${destStudySAKeys[0]} --account-name $destStudySA | jq -r '.[] | .name + "  " + .properties.contentSettings.contentMd5' >> ~/destHashes.txt
  done
else
  srcStudySAInfo=$(az storage account show -n $srcStudySA -g $srcRg)
fi

echo "Moving study storage ${srcStudySA} to resource group ${destRg}"
srcStudySAId=$(echo "$srcStudySAInfo" | jq -r '.id')
az resource move --destination-group $destRg --ids $srcStudySAId

stopTime=$(date)

$SCRIPT_DIR/ice-system.sh deice $destRg
$SCRIPT_DIR/ice-ancillary.sh deice $destRg

echo "Began: ${beginTime}    Complete: $(date)"
echo "Start: ${startTime}    Stop: ${stopTime}"

echo "================================================================="
echo "             Post-migration Values"
echo "================================================================="
echo " Storage Account: $srcStudySA"
echo " Storage Key:     ${srcStudySAKeys[0]}"
