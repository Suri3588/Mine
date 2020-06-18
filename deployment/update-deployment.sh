#!/usr/bin/env bash

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

if [ "$1" == "--skip-jump-box-shutdown" ]; then
    skipShutdown=true
else
    skipShutdown=false
fi

pushd $scriptDir > /dev/null
. ./extract-secrets.sh --silent
if [ $? -ne 0 ]; then
    exit 1
fi
popd > /dev/null

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$projectsDir" ]; then
    echo "No Projects directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$terraformDir" ]; then
    echo "No Terraform directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$secretsDir" ]; then
    echo "No Secrets directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

echo "starting jumpbox..."
az vm start -g $resourceGroup -n jump
if [ $? -ne 0 ]; then
    echo "An error has occurred starting the jumpbox"
    exit 1
fi

# setup the kubernetes config file
KUBECONFIG=$deploymentDir/$secretsDir/k8s-conf 
export KUBECONFIG
kubectl config use-context "api-deployment-account-default-$resourceGroup-aks"
kubectl get pods --all-namespaces

# find the current principal IDs
aadUpdate=false
principalUpdate=false

principalId=$(az aks show --resource-group $resourceGroup --name $resourceGroup-aks --query servicePrincipalProfile.clientId -o tsv)
if [ -z "$principalId" ]; then
    echo "Unable to find the current service principal ID for $resourceGroup-aks"
    exit 1
fi

aadClientPrincipalId=$(az aks show --resource-group $resourceGroup --name $resourceGroup-aks | jq -r .aadProfile.clientAppId)
if [ -z "$aadClientPrincipalId" ]; then
    echo "Unable to find the current AAD Client service principal ID for $resourceGroup-aks"
    exit 1
fi

aadServerPrincipalId=$(az aks show --resource-group $resourceGroup --name $resourceGroup-aks | jq -r .aadProfile.serverAppId)
if [ -z "$aadServerPrincipalId" ]; then
    echo "Unable to find the current AAD Server service principal ID for $resourceGroup-aks"
    exit 1
fi

# check for service principal change and add role assignments to new service principal
if [ "$principalId" != "$akcPrincipal" ]; then
    principalName=$(az ad sp show --id $principalId | jq -r .displayName)
    if [ -z "$principalName" ]; then
        echo "Unable to find the name of service principal $principalId"
        exit 1
    fi

    akcPrincipalName=$(az ad sp show --id $akcPrincipal | jq -r .displayName)
    if [ -z "$akcPrincipalName" ]; then
        echo "Unable to find the name of service principal $akcPrincipal"
        exit 1
    fi

    echo "Detected AKS service principal change: $principalName -> $akcPrincipalName"
    principalUpdate=true

    aksResGroupId=$(az group show --name $resourceGroup-aks | jq -r .id)
    if [ -z "$aksResGroupId" ]; then
        echo "Unable to find the ID for resource group $resourceGroup-aks"
        exit 1
    fi

    ipResGroupId=$(az group show --name $resourceGroup-ip | jq -r .id)
    if [ -z "$ipResGroupId" ]; then
        echo "Unable to find the ID for resource group $resourceGroup-ip"
        exit 1
    fi

    echo "Adding service principal $akcPrincipalName to resource group $resourceGroup-aks"
    az role assignment create --assignee $akcPrincipal --role 'Contributor' --scope $aksResGroupId > /dev/null
    if [ $? -ne 0 ]; then
        echo "An error has occurred adding service principal $akcPrincipalName to resource group $resourceGroup-aks"
        exit 1
    fi

    echo "Adding service principal $akcPrincipalName to resource group $resourceGroup-ip"
    az role assignment create --assignee $akcPrincipal --role 'Contributor' --scope $ipResGroupId > /dev/null
    if [ $? -ne 0 ]; then
        echo "An error has occurred adding service principal $akcPrincipalName to resource group $resourceGroup-ip"
        exit 1
    fi

    if [ "$isSharedService" != "true" ]; then
        vnetId=$(az network vnet show --resource-group $resourceGroup --name $resourceGroup-network | jq -r .id)
        if [ -z "$vnetId" ]; then
            echo "Unable to find the ID for virtual network $resourceGroup-network"
            exit 1
        fi

        echo "Adding service principal $akcPrincipalName to virtual network $resourceGroup-network"
        az role assignment create --assignee $akcPrincipal --role 'Network Contributor' --scope $vnetId > /dev/null
        if [ $? -ne 0 ]; then
            echo "An error has occurred adding service principal $akcPrincipalName to virtual network $resourceGroup-network"
            exit 1
        fi
    else
        vnetId=$(az network vnet show --resource-group $resourceGroup --name $resourceGroup-vnet | jq -r .id)
        if [ -z "$vnetId" ]; then
            echo "Unable to find the ID for virtual network $resourceGroup-vnet"
            exit 1
        fi

        echo "Adding service principal $akcPrincipalName to virtual network $resourceGroup-vnet"
        az role assignment create --assignee $akcPrincipal --role 'Network Contributor' --scope $vnetId > /dev/null
        if [ $? -ne 0 ]; then
            echo "An error has occurred adding service principal $akcPrincipalName to virtual network $resourceGroup-vnet"
            exit 1
        fi
    fi
fi

# check for AAD service principal changes
if [ "$aadClientPrincipalId" != "$aksAadClientId" ]; then
    echo "Detected AKS AAD client service principal change: $aadClientPrincipalId -> $aksAadClientId"
    aadUpdate=true
fi

if [ "$aadServerPrincipalId" != "$aksAadServerId" ]; then
    echo "Detected AKS AAD server service principal change: $aadServerPrincipalId -> $aksAadServerId"
    aadUpdate=true
fi

# check for forced service principal updates
if [ "$forceServicePrincipalUpdates" == "true" ]; then
    echo "forceServicePrincipalUpdates = true"
    principalUpdate=true
    aadUpdate=true
fi

# update the kubernetes cluster with any new service principals
if [ "$principalUpdate" == "true" ]; then
    echo "Updating Kubernetes service principal"
    az aks update-credentials --resource-group $resourceGroup --name $resourceGroup-aks \
        --reset-service-principal --service-principal $akcPrincipal --client-secret $akcPrincipalPassword

    if [ $? -ne 0 ]; then
        echo "An error has occurred updating the Kubernetes service principal"
        exit 1
    fi
fi

if [ "$aadUpdate" == "true" ]; then
    echo "Updating Kubernetes AAD service principals"
    az aks update-credentials --resource-group $resourceGroup --name $resourceGroup-aks \
        --reset-service-principal --service-principal $akcPrincipal --client-secret $akcPrincipalPassword
        
    if [ $? -ne 0 ]; then
        echo "An error has occurred updating the Kubernetes AAD service principals"
        exit 1
    fi
fi

# remove role assignments from old service principals
if [ "$principalId" != "$akcPrincipal" ]; then
    echo "Removing service principal $principalName from resource group $resourceGroup-aks"
    az role assignment delete --assignee $principalId --role 'Contributor' --scope $aksResGroupId --yes > /dev/null
    if [ $? -ne 0 ]; then
        echo "An error has occurred removing service principal $principalName from resource group $resourceGroup-aks"
        exit 1
    fi

    echo "Removing service principal $principalName from resource group $resourceGroup-ip"
    az role assignment delete --assignee $principalId --role 'Contributor' --scope $ipResGroupId --yes > /dev/null
    if [ $? -ne 0 ]; then
        echo "An error has occurred removing service principal $principalName from resource group $resourceGroup-ip"
        exit 1
    fi

    if [ "$isSharedService" != "true" ]; then
        echo "Removing service principal $principalName from virtual network $resourceGroup-network"
        az role assignment delete --assignee $principalId --role 'Network Contributor' --scope $vnetId --yes > /dev/null
        if [ $? -ne 0 ]; then
            echo "An error has occurred removing service principal $principalName from virtual network $resourceGroup-network"
            exit 1
        fi
    else
        echo "Removing service principal $principalName from virtual network $resourceGroup-vnet"
        az role assignment delete --assignee $principalId --role 'Network Contributor' --scope $vnetId --yes > /dev/null
        if [ $? -ne 0 ]; then
            echo "An error has occurred removing service principal $principalName from virtual network $resourceGroup-vnet"
            exit 1
        fi
    fi
fi

# update terraform
pushd $deploymentDir/$terraformDir  > /dev/null
echo "yes" | terraform init
if [ $? -ne 0 ]; then
    echo "An error has occurred initializing the terraform modules"
    exit 1
fi

echo "yes" | terraform apply -auto-approve
if [ $? -ne 0 ]; then
    echo "An error has occurred updating terraform"
    exit 1
fi
popd > /dev/null

# update the jumpbox
pushd $deploymentDir/$projectsDir/jumpbox > /dev/null
./run_ansible.sh nucleus $deploymentDir/$secretsDir/ssh_rsa $deploymentDir/$secretsDir/jumpbox.json
if [ $? -ne 0 ]; then
    echo "An error occurred updating the jumpbox" 
    exit 1
fi
popd > /dev/null

# update the passthru
pushd $deploymentDir/$projectsDir/passthru > /dev/null
./run_ansible.sh nucleus $deploymentDir/$secretsDir/ssh_rsa $deploymentDir/$secretsDir/passthru.json $deploymentDir/$secretsDir/passthru-local.json
if [ $? -ne 0 ]; then
    echo "An error occurred updating the passthru" 
    exit 1
fi
popd > /dev/null

# update the baseline project
pushd $deploymentDir/$projectsDir/baseline > /dev/null
./deploy.sh
if [ $? -ne 0 ]; then
    echo "An error occurred updating the baseline project" 
    exit 1
fi
popd > /dev/null

if [ "$isSharedService" == "true" ]; then
    # update the logging project
    pushd $deploymentDir/$projectsDir/logging > /dev/null
    ./deploy.sh
    if [ $? -ne 0 ]; then
        echo "An error occurred updating the nucleus project"
        exit 1
    fi
    popd > /dev/null
else
    # update the nucleus projects
    pushd $deploymentDir/$projectsDir/nucleus > /dev/null
    ./deploy.sh
    if [ $? -ne 0 ]; then
        echo "An error occurred updating the nucleus project"
        exit 1
    fi
    popd > /dev/null
fi

if [ "$skipShutdown" == "false" ]; then
    echo "deallocating jumpbox..."
    az vm deallocate -g $resourceGroup -n jump
    if [ $? -ne 0 ]; then
        echo "An error has occurred starting the jumpbox"
        exit 1
    fi
fi

exit 0