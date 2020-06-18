#!/usr/bin/env bash

delete=$1

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
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

if [ "$delete" == "--delete" ]; then
    echo -e "Are you sure you want to delete secrets from the $vaultName Key Vault (yes|\033[1mno\033[0m)?"
    read answer
    if [ "${answer,,}" != "yes" ]; then
        exit 0
    fi
fi

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
pushd $scriptDir > /dev/null

function process_line {
    local file=$1
    local line=$2

    if [ -z "$filePath" ]; then
        return
    fi

    if [ -z "$line" ]; then
        return
    fi

    file=$(echo $line | awk '{print $2}')
    if [ "$file" == "secretsDir" ]; then
        return
    fi

    if [ "$file" != "$fileName" ]; then
        echo "$file was not found in secrets-vars.txt, skipping"
        return
    fi

    what=$(echo $line | awk '{print $1}')
    if [ "$what" != "FILE" ]; then
        echo "The operation for $file was $what in secrets-vars.txt, skipping"
        return
    fi

    key=$(echo $line | awk '{print $3}')
    if [ -z "$key" ]; then
        echo "No key for $file was found in secrets-vars.txt, skipping"
        return
    fi

    az keyvault secret show --name "$key" --vault-name "$vaultName" --query value -o tsv &> /dev/null
    if [ $? -eq 0 ]; then
        if [ "$delete" != "--delete" ]; then
            echo "The key $key already exists in $vaultName, skipping"
            return
        fi
    elif [ "$delete" == "--delete" ]; then
        echo "The key $key does not exist in $vaultName, skipping"
        return
    fi

    if [ "$delete" == "--delete" ]; then 
        echo -e "Do you want to delete the \033[1m$key\033[0m secret from the $vaultName Key Vault (yes|\033[1mno\033[0m)?"
        read answer
        if [ "${answer,,}" != "yes" ]; then
            echo "Skipping the deletion of $key from $vaultName"
            return
        fi

        az keyvault secret delete --name "$key" --vault-name "$vaultName" > /dev/null
        if [ $? -eq 0 ]; then
            echo "The key $key has been deleted from $vaultName"
        else
            echo "An error has occurred deleting key $key from $vaultName"
        fi
    else
        az keyvault secret set --name "$key" --vault-name "$vaultName" --file "$filePath" > /dev/null
        if [ $? -eq 0 ]; then
            echo "The file $filePath has been uploaded to $vaultName with key $key"
        else
            echo "An error has occurred uploading $filePath to $vaultName with key $key"
        fi
    fi
}

# upload any files in the secrets directory with a corrosponding key in the secrets file to the key vault
files=$(find $deploymentDir/$secretsDir -name "*")
for filePath in $files; do 
    fileName=$(basename "${filePath%}")
    line=$(grep "$fileName" $deploymentDir/secret-vars.txt)
    process_line "$filePath" "$line"
done

exit 0
