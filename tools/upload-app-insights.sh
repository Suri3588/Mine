#!/usr/bin/env bash

if [ -z "$resourceGroup" ]; then
    echo "The resourceGroup is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$vaultName" ]; then
    echo "No vault name specified in secret-vars.txt"
    exit 1
fi

if [ -z "$deploymentDir" ]; then
    echo "No deployment directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$secretsDir" ]; then
    echo "No secrets directory specified in secret-vars.txt"
    exit 1
fi

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null && pwd )"
pushd $scriptDir > /dev/null

if [ "$1" == "--delete" ]; then
    echo -e "Are you sure you want to delete secrets from the $vaultName Key Vault (yes|\033[1mno\033[0m)?"
    read answer
    if [ "${answer,,}" != "yes" ]; then
        exit 0
    fi

    az keyvault secret delete --name "appInsightsKey-$resourceGroup" --vault-name "$vaultName" > /dev/null
    if [ $? -eq 0 ]; then
        echo "The key appInsightsKey-$resourceGroup has been deleted from $vaultName"
        exit 0
    else
        echo "An error has occurred deleting the key appInsightsKey-$resourceGroup from $vaultName"
        exit 1
    fi
fi

echo "Retrieving the shared services Application Insights key..."

az extension add --name application-insights 2> /dev/null
if [ $? -ne 0 ]; then
    echo "Unable to add the application-insights extension."
    exit 1
fi

appInsightsKey=$(az monitor app-insights component show --resource-group $resourceGroup --app app-insights | jq -r .instrumentationKey)
if [ $? -ne 0 ]; then
    echo "Unable to retrieve the Application Insights key."
    exit 1
fi

echo "Application Insights key: $appInsightsKey"

base64key=$(echo -n $appInsightsKey | base64)
filePath=$deploymentDir/$secretsDir/app-insights-secrets.yaml
cp $scriptDir/templates/app-insights-secrets.yaml.j2 $filePath
sed -i "s/{{ appInsightsKey }}/$base64key/" "$filePath"

az keyvault secret set --name "appInsightsKey-$resourceGroup" --vault-name "$vaultName" --file "$filePath" > /dev/null
if [ $? -ne 0 ]; then
    echo "An error occurred uploading the application-insights key to keyvault $vaultName."
    exit 1
fi

echo "The Application Insights key has been added to the keyvault."
exit 0
