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

if [ -z "$subscriptionId" ]; then
    echo "No subscription ID specified in secret-vars.txt"
    exit 1
fi

if [ -z "$isSharedService" ]; then
    echo "The isSharedService is not set, run extract-secrets.sh"
    exit 1
fi

procfile=$1
concise=false
testSystem=false
frameAncestors=""
shift

while [ -n "$1" ]; do
	case "$1" in
        "--concise")
            concise=true
            shift
            ;;
        "--test")
            testSystem=true
            shift
            ;;
        *)
            echo "Error: Unknown command: $1"
            exit 1
	esac
done

if [ -z "$procfile" ]; then
    if [ "$isSharedService" == "false" ]; then
        echo "You must provide processes_all_separate.json from the old system"
        exit 1
    fi
else
    if [ ! -f "$procfile" ]; then
        echo "The file $procfile does not exist"
        exit 1
    fi
fi

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# set the subscription for all future azure cli operations
az account set -s $subscriptionId

# create the directories and copy their contents
rm -rf $deploymentDir/$modulesDir
rm -rf $deploymentDir/$projectsDir
mkdir $deploymentDir/$modulesDir
mkdir $deploymentDir/$projectsDir 
mkdir -p $deploymentDir/$secretsDir 
mkdir -p $deploymentDir/$terraformDir 

localModules=$scriptDir/../projects/provisioner/scripts/terraform/modules

if [ "$isSharedService" == "false" ]; then
    # gzip and base64 encode processes_all_separate.json for upload to the key vault
    # this can be extracted with: cat $deploymentDir/$secretsDir/processes_all_separate.gz.64 | base64 --decode | gzip -d > <<out file>>
    gzip -c $procfile | base64 > $deploymentDir/$secretsDir/processes_all_separate.gz.64
    cp -a $procfile $deploymentDir/$secretsDir
    cp -a $scriptDir/../projects/nucleus $deploymentDir/$projectsDir

    if [ "$testSystem" == "true" ]; then
        frameAncestors="; frame-ancestors https://jsfiddle.net https://fiddle.jshell.net https://concise-dev.vitalhealthsoftware.com/ https://concise-test.vitalhealthsoftware.com/ https://concise-stage.vitalhealthsoftware.com/ https://concise-stage.medtronic.com/ https://concise-demo.medtronic.com/ https://www.conciseoutcomes.com https://concise-dev.medtronic.com"
    elif [ "$concise" == "true" ]; then
        frameAncestors="; frame-ancestors https://concise-dev.vitalhealthsoftware.com/ https://concise-test.vitalhealthsoftware.com/ https://concise-stage.vitalhealthsoftware.com/ https://concise-stage.medtronic.com/ https://concise-demo.medtronic.com/ https://www.conciseoutcomes.com https://concise-dev.medtronic.com"
    fi
else
    cp -a $scriptDir/../projects/logging $deploymentDir/$projectsDir
    cp -a $localModules/resgroup $deploymentDir/$modulesDir/
fi

export frameAncestors

cp -a $scriptDir/../projects/baseline $deploymentDir/$projectsDir
cp -a $scriptDir/../projects/ansible $deploymentDir/$projectsDir
cp -a $scriptDir/../projects/jumpbox $deploymentDir/$projectsDir
cp -a $scriptDir/../projects/passthru $deploymentDir/$projectsDir

cp -a $localModules/publicIp/ $deploymentDir/$modulesDir/publicIp
cp -a $localModules/jumpbox/ $deploymentDir/$modulesDir/jumpbox
cp -a $localModules/kubegroup/ $deploymentDir/$modulesDir/kubegroup
cp -a $localModules/passthru/ $deploymentDir/$modulesDir/passthru


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

# render the jinja templates for terraform
if [ "$isSharedService" == "false" ]; then
    templates=("azure.tf.remote" "azure.tf.local" "nk8s.tf" "variables.tf")
else
    templates=("azure.tf.remote" "azure.tf.local" "sharedServices.tf" "sharedServicesVariables.tf")
fi

for file in "${templates[@]}"; do
    echo "rendering file: $scriptDir/templates/$file"
    if [ -e $file ]; then
        rm $file
    fi

    python renderJ2File.py $scriptDir/templates/$file.j2 $scriptDir/temp/environment.json
    if [ $? -ne 0 ]; then
        echo "An error occurred rendering the file $file.j2"
        exit 1
    fi
    mv $scriptDir/templates/$file $deploymentDir/$terraformDir
done

# render the jinja templates for kubernetes - write the list to a file for identication
find $deploymentDir/$projectsDir/baseline -name "*.j2" > $scriptDir/temp/renderlist.txt 

if [ "$isSharedService" == "false" ]; then
    find $deploymentDir/$projectsDir/nucleus -name "*.j2" >> $scriptDir/temp/renderlist.txt
else
    find $deploymentDir/$projectsDir/logging -name "*.j2" >> $scriptDir/temp/renderlist.txt
fi

while read file; do
    outFile="${file%.*}"
    echo "rendering file: $outFile"
    if [ -e $outFile ]; then
        rm $outFile
    fi

    python renderJ2File.py $file $scriptDir/temp/environment.json
    if [ $? -ne 0 ]; then
        echo "An error occurred rendering the file $file"
        exit 1
    fi
    rm $file
done < $scriptDir/temp/renderlist.txt

# make all of the shell scripts that were rendered executable
echo ""
find $deploymentDir/$projectsDir -name "*.sh" -exec chmod u+x {} \;

if [ "$isSharedService" == "false" ]; then
    # Generate the kubernetes configuration files
    pushd createK8sConfigs > /dev/null
    npm install
    if [ $? -ne 0 ]; then
        echo "An error occurred running npm install"
        exit 1
    fi

    bin/createK8sConfigs k8s --repodir $deploymentDir --procfile $procfile --execute
    if [ $? -ne 0 ]; then
        echo "An error occurred creating the kubernetes secrets files"
        exit 1
    fi
    popd > /dev/null
fi

echo ""
exit 0
