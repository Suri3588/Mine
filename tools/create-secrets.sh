#!/usr/bin/env bash

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

if [ -z "$vaultName" ]; then
    echo "No vault name specified in secret-vars.txt"
    exit 1
fi

if [ -z "$secretsDir" ]; then
    echo "No secrets directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$isSharedService" ]; then
    echo "The isSharedService is not set, run extract-secrets.sh"
    exit 1
fi

while [ -n "$1" ]; do
	case "$1" in
        "--skip-ssh")
            skipssh=true
            shift
            ;;
        "--skip-upload")
            skipUpload=true
            shift
            ;;
        "--delete")
            delete=true
            shift
            ;;
        *)
            echo "Error: Unknown command: $1"
            exit 1
	esac
done

secretsFile="$deploymentDir/$secretsDir/secret-vars.txt"
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

if [ "$delete" == "true" ]; then
    echo -e "\x1b[91mWARNING: this command will do the following:\x1b[0m"
    echo ""
    echo -e "\033[1mDelete the following values in the $vaultName KeyVault:\033[0m"
    echo ""
    echo "    sshPrivateKey-$resourceGroup"
    echo "    sshPublicKey-$resourceGroup"
    echo "    regaksPrivateKey-$resourceGroup"
    echo "    regaksPublicKey-$resourceGroup"
    echo "    dhparam-$resourceGroup"
    echo "    cookieSecret-$resourceGroup"
    if [ "$isSharedService" == "true" ]; then
        echo "    grafanaAdminPassword-$resourceGroup"
        echo "    elasticsearchPassword-$resourceGroup"
        echo "    elasticsearchReadOnlyPassword-$resourceGroup"
        echo "    kibanaPassword-$resourceGroup"
        echo "    kibanaAdminPassword-$resourceGroup"
        echo "    beatsPassword-$resourceGroup"
    else
        echo "    beatsElasticsearchToken-$resourceGroup"
    fi
    echo ""
    echo ""
    echo -en "\033[1mAre you sure you want to continue (\033[0myes|\033[1mno)?\033[0m "

    read answer
    if [ "${answer,,}" != "yes" ]; then
        exit 0
    fi

    az keyvault secret delete --name "sshPrivateKey-$resourceGroup"    --vault-name "$vaultName" > /dev/null
    az keyvault secret delete --name "sshPublicKey-$resourceGroup"     --vault-name "$vaultName" > /dev/null
    az keyvault secret delete --name "regaksPrivateKey-$resourceGroup" --vault-name "$vaultName" > /dev/null
    az keyvault secret delete --name "regaksPublicKey-$resourceGroup"  --vault-name "$vaultName" > /dev/null
    az keyvault secret delete --name "dhparam-$resourceGroup"          --vault-name "$vaultName" > /dev/null
    az keyvault secret delete --name "cookieSecret-$resourceGroup"     --vault-name "$vaultName" > /dev/null

    if [ "$isSharedService" == "true" ]; then
        az keyvault secret delete --name "grafanaAdminPassword-$resourceGroup" --vault-name "$vaultName" > /dev/null
        az keyvault secret delete --name "elasticsearchPassword-$resourceGroup" --vault-name "$vaultName" > /dev/null
        az keyvault secret delete --name "elasticsearchReadOnlyPassword-$resourceGroup" --vault-name "$vaultName" > /dev/null
        az keyvault secret delete --name "kibanaPassword-$resourceGroup" --vault-name "$vaultName" > /dev/null
        az keyvault secret delete --name "kibanaAdminPassword-$resourceGroup" --vault-name "$vaultName" > /dev/null
        az keyvault secret delete --name "beatsPassword-$resourceGroup" --vault-name "$vaultName" > /dev/null
    else
        az keyvault secret delete --name "beatsElasticsearchToken-$resourceGroup" --vault-name "$vaultName" > /dev/null
    fi

    echo ""
    echo "The secrets have been deleted from $vaultName"

    exit 0
fi

echo -e "\x1b[91mWARNING: this command will do the following:\x1b[0m"
echo ""
echo -e "\033[1mOverwrite the current files in $deploymentDir/$secretsDir:\033[0m"
echo ""

if [ "$skipssh" != "true" ]; then
    echo "    ssh_rsa"
    echo "    ssh_rsa.pub"
fi

echo "    regaks_rsa"
echo "    regaks_rsa.pub"
echo "    dhparam.pem"
echo ""

if [ "$skipUpload" != "true" ]; then
    echo -e "\033[1mCreate or replace the following values in the $vaultName KeyVault:\033[0m"
    echo ""
    echo "    sshPrivateKey-$resourceGroup"
    echo "    sshPublicKey-$resourceGroup"
    echo "    regaksPrivateKey-$resourceGroup"
    echo "    regaksPublicKey-$resourceGroup"
    echo "    dhparam-$resourceGroup"
    echo "    cookieSecret-$resourceGroup"
    if [ "$isSharedService" == "true" ]; then
        echo "    grafanaAdminPassword-$resourceGroup"
        echo "    elasticsearchPassword-$resourceGroup"
        echo "    elasticsearchReadOnlyPassword-$resourceGroup"
        echo "    kibanaPassword-$resourceGroup"
        echo "    kibanaAdminPassword-$resourceGroup"
        echo "    beatsPassword-$resourceGroup"
    else
        echo "    beatsElasticsearchToken-$resourceGroup"
    fi
    echo ""
    echo ""
fi

echo -en "\033[1mAre you sure you want to continue (\033[0myes|\033[1mno)?\033[0m "

read answer
if [ "${answer,,}" != "yes" ]; then
    exit 0
fi

if [ "$skipssh" != "true" ]; then
    echo y | ssh-keygen -t rsa -b 2048 -P "" -f $deploymentDir/$secretsDir/ssh_rsa 
fi

echo y | ssh-keygen -t rsa -b 2048 -P "" -f $deploymentDir/$secretsDir/regaks_rsa
openssl dhparam -out $deploymentDir/$secretsDir/dhparam.pem 2048

cookieSecret=""
for i in {1..10}; do 
    cookieSecret=$cookieSecret$(printf "%x\n" "$((0 + RANDOM % 255))")
done

echo "The cookieSecret has been created: $cookieSecret"

if [ "$isSharedService" == "true" ]; then
    grafanaAdminPassword=`pwgen -s 40 1`
    echo "The grafana admin password has been created: $grafanaAdminPassword"
    elasticsearchPassword=`pwgen -s 40 1`
    echo "The elasticsearch password has been created: $elasticsearchPassword"
    elasticsearchReadOnlyPassword=`pwgen -s 40 1`
    echo "The elasticsearch read-only password has been created: $elasticsearchReadOnlyPassword"
    kibanaPassword=`pwgen -s 40 1`
    echo "The kibana password has been created: $kibanaPassword"
    kibanaAdminPassword=`pwgen -s 40 1`
    echo "The kibana admin password has been created: $kibanaAdminPassword"
    beatsPassword=`pwgen -s 40 1`
    echo "The beats password has been created: $beatsPassword"
else
    beatsElasticsearchToken=`pwgen -s 64 1`
    echo "The beats elasticsearch token has been created: $beatsElasticsearchToken"
fi

setValueSecret() {
    local SECRET_NAME="$1"
	local VALUE="$2"

    az keyvault secret set --name "$SECRET_NAME-$resourceGroup" --vault-name "$vaultName" --value "$VALUE" > /dev/null

    if [ $? -ne 0 ]; then
        echo "An error occurred creating the $SECRET_NAME-$resourceGroup key in the $vaultName keyvault"
        exit 1
    fi
}

setFileSecret() {
    local SECRET_NAME="$1"
	local FILE="$2"

    az keyvault secret set --name "$SECRET_NAME-$resourceGroup" --vault-name "$vaultName" --file "$FILE" > /dev/null

    if [ $? -ne 0 ]; then
        echo "An error occurred creating the $SECRET_NAME-$resourceGroup key in the $vaultName keyvault"
        exit 1
    fi
}

if [ "$skipUpload" == "true" ]; then
    echo ""
    echo "The secrets have been generated, uploading skipped"
else
    setFileSecret "sshPrivateKey" "$deploymentDir/$secretsDir/ssh_rsa"
    setFileSecret "sshPublicKey" "$deploymentDir/$secretsDir/ssh_rsa.pub"
    setFileSecret "regaksPrivateKey" "$deploymentDir/$secretsDir/regaks_rsa"
    setFileSecret "regaksPublicKey" "$deploymentDir/$secretsDir/regaks_rsa.pub"
    setFileSecret "dhparam" "$deploymentDir/$secretsDir/dhparam.pem"
    setValueSecret "cookieSecret" "$cookieSecret"

    if [ "$isSharedService" == "true" ]; then
        setValueSecret "grafanaAdminPassword" "$grafanaAdminPassword"
        setValueSecret "elasticsearchPassword" "$elasticsearchPassword"
        setValueSecret "elasticsearchReadOnlyPassword" "$elasticsearchReadOnlyPassword"
        setValueSecret "kibanaPassword" "$kibanaPassword"
        setValueSecret "kibanaAdminPassword" "$kibanaAdminPassword"
        setValueSecret "beatsPassword" "$beatsPassword"
    else
        setValueSecret "beatsElasticsearchToken" "$beatsElasticsearchToken"
    fi

    echo ""
    echo "The secrets have been generated and uploaded to $vaultName"
fi

exit 0
