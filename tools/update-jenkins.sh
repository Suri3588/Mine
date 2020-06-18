#!/usr/bin/env bash

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

if [ -z "$subscriptionId" ]; then
    echo "No subscription ID specified in secret-vars.txt"
    exit 1
fi

if [ -z "$dnsPrefix" ]; then
    echo "No DNS prefix specified secret-vars.txt"
    exit 1
fi

if [ -z "$deployDomain" ]; then
    echo "No deploy domain specified secret-vars.txt"
    exit 1
fi

if [ -z "$dockerRegistry" ]; then
    echo "No docker registry specified secret-vars.txt"
    exit 1
fi

if [ -z "$jenkinsServicePrincipal" ]; then
    echo "No jenkinsServicePrincipal specified secret-vars.txt"
    exit 1
fi

if [ -z "$jenkinsBuildType" ]; then
    echo "No jenkinsBuildType specified secret-vars.txt"
    exit 1
fi

if [ -z "$isSharedService" ]; then
    echo "The isSharedService is not set, run extract-secrets.sh"
    exit 1
fi

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# set the subscription for all future azure cli operations
az account set -s $subscriptionId

# create the environment.json file
pushd $scriptDir > /dev/null

if [ "$isSharedService" == "false" ]; then
    ./create-environment-info.sh > $scriptDir/temp/environment.json
else
    ./create-shared-services-environment-info.sh > $scriptDir/temp/environment.json
fi

if [ $? -ne 0 ]; then
    echo "An error occurred creating the environment configuration file"
    exit 1
fi

# render the jinja template for Jenkins
if [ "$isSharedService" == "false" ]; then
    echo "rendering file: $scriptDir/templates/Jenkinsfile.dev"
    python renderJ2File.py $scriptDir/templates/dev.jenkinsfile.j2 $scriptDir/temp/environment.json
else
    echo "rendering file: $scriptDir/templates/Jenkinsfile.sharedServices.dev"
    python renderJ2File.py $scriptDir/templates/sharedServices.dev.jenkinsfile.j2 $scriptDir/temp/environment.json
fi

if [ $? -ne 0 ]; then
    echo "An error occurred rendering the file Jenkinsfile.dev.j2"
    exit 1
fi

if [ -e $scriptDir/../Jenkinsfile.dev ]; then
    rm $scriptDir/../Jenkinsfile.dev
fi

if [ "$isSharedService" == "false" ]; then
    mv $scriptDir/templates/dev.jenkinsfile $scriptDir/../Jenkinsfile.dev
else
    mv $scriptDir/templates/sharedServices.dev.jenkinsfile $scriptDir/../Jenkinsfile.dev
fi

if [ $? -ne 0 ]; then
    echo "An error occurred copying Jenkinsfile.dev to the root directory"
    exit 1
fi

exit 0
