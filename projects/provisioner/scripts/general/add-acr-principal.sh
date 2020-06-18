#!/bin/bash
if [ $# -ne 3 ]; then
  echo "usage: $0 container-registry-name service-principle-name role"
  exit 0
fi

# Set parameters
acrName=$1
aspName=$2
acrRole=$3

# Get the ID of the container registry
acrId=$(az acr show --name $acrName --query id --output tsv)

# Generate the service principle
aspPassword=$(az ad sp create-for-rbac --name $aspName --scopes $acrId --role $acrRole --query password --output tsv)
aspAppId=$(az ad sp show --id http://$aspName --query appId --output tsv)

echo "Service Principle ID: $aspAppId"
echo "Service Principle password: $aspPassword"

