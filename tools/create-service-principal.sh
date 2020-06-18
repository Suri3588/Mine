#!/usr/bin/env bash

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

if [ -z "$vaultName" ]; then
    echo "No subscription ID specified in secret-vars.txt"
    exit 1
fi

if [ "$1" == "--delete" ]; then
    echo -e "Are you sure you want to delete the akcPrincipal-$resourceGroup and KeyVault entries (yes|\033[1mno\033[0m)?"
    read answer
    if [ "${answer,,}" != "yes" ]; then
        exit 0
    fi

    id=$(az ad sp list --display-name akcPrincipal-$resourceGroup --query "[].{id:objectId}" | grep "id" | awk '{print $2}' | tr -d '"')
    if [ -z "$id" ]; then
        echo "An error occurred finding the akcPrincipal-$resourceGroup service principal"
    else
        az ad sp delete --id $id > /dev/null
        if [ $? -ne 0 ]; then
            echo "An error occurred deleting the akcPrincipal-$resourceGroup service principal"
        fi
    fi

    az keyvault secret delete --name "akcPrincipal-$resourceGroup"    --vault-name "$vaultName" > /dev/null
    az keyvault secret delete --name "akcPrincipalPassword-$resourceGroup"    --vault-name "$vaultName" > /dev/null
 
    echo "The key akcPrincipal-$resourceGroup service principal and KeyVault entries have been deleted"

    exit 0
fi

exists=$(az ad sp list --display-name akcPrincipal-$resourceGroup)
if [ "$exists" != "[]" ]; then
    echo "The service principal akcPrincipal-$resourceGroup already exists"
    exit 1
fi

years=$1
if [ -z "$years" ]; then
    years=2
fi

az keyvault secret show --name "akcPrincipal-$resourceGroup" --vault-name $vaultName --query value -o tsv &> /dev/null
if [ $? -eq 0 ]; then
    echo "The key akcPrincipal-$resourceGroup already exists in the $vaultName keyvault"
    exit 1
fi

az keyvault secret show --name "akcPrincipalPassword-$resourceGroup" --vault-name $vaultName --query value -o tsv &> /dev/null
if [ $? -eq 0 ]; then
    echo "The key akcPrincipalPassword-$resourceGroup already exists in the $vaultName keyvault"
    exit 1
fi

info=$(az ad sp create-for-rbac --skip-assignment --years $years --name akcPrincipal-$resourceGroup 2> /dev/null)
if [ $? -ne 0 ]; then
    echo "An error occurred creating the akcPrincipal-$resourceGroup service principal"
    exit 1
fi

displayName=$(echo $info | jq -r .displayName)
appId=$(echo $info | jq -r .appId)
password=$(echo $info | jq -r .password)

echo "Created service principal $displayName:"
echo "    Application ID: $appId"
echo "    Password: $password"
echo ""

az keyvault secret set --name akcPrincipal-$resourceGroup --vault-name $vaultName --value $appId > /dev/null
if [ $? -ne 0 ]; then
    echo "An error occurred creating the akcPrincipal-$resourceGroup key in the $vaultName keyvault"
    exit 1
fi

echo "The key akcPrincipal-$resourceGroup has been created in the $vaultName keyvault"

az keyvault secret set --name akcPrincipalPassword-$resourceGroup --vault-name $vaultName --value $password > /dev/null
if [ $? -ne 0 ]; then
    echo "An error occurred creating the akcPrincipalPassword-$resourceGroup key in the $vaultName keyvault"
    exit 1
fi

echo "The key akcPrincipalPassword-$resourceGroup has been created in the $vaultName keyvault"
