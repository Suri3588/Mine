#!/usr/bin/env bash

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$modulesDir" ]; then
    echo "No Modules directory specified in secret-vars.txt"
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

# clean the deployment folder
echo -en "Are you sure you want to clean the $deploymentDir directory (yes|\033[1mno\033[0m)? "
read answer
if [ "${answer,,}" != "yes" ]; then
    exit 0
fi

echo ""
echo "Cleaning $deploymentDir folder"

rm -rf $deploymentDir/$modulesDir
rm -rf $deploymentDir/$projectsDir
rm -rf $deploymentDir/$secretsDir
rm -rf $deploymentDir/$terraformDir

exit 0
