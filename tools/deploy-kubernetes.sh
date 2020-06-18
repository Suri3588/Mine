#!/usr/bin/env bash

renderSharedServices=false

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

if [ -z "$projectsDir" ]; then
    echo "No projects directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$secretsDir" ]; then
    echo "No Secrets directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$isSharedService" ]; then
    echo "The isSharedService is not set, run extract-secrets.sh"
    exit 1
fi

KUBECONFIG=$deploymentDir/$secretsDir/k8s-conf 
export KUBECONFIG
kubectl config use-context "api-deployment-account-default-$resourceGroup-aks"
kubectl get pods --all-namespaces

deployProject() {
    local project="$1"

    pushd $deploymentDir/$projectsDir/$project > /dev/null
    ./deploy.sh
    if [ $? -ne 0 ]; then
        echo "An error occurred running the $project deployment" 
        exit 1
    fi
    popd > /dev/null
}

# deploy the baseline project
deployProject "baseline"

if [ "$isSharedService" == "false" ]; then
    # deploy the nucleus project
    deployProject "nucleus"
else
    # deploy the logging project
    deployProject "logging"
fi

exit 0
