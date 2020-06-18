#!/usr/bin/env bash

if [ "$1" == "--help" ]; then
  echo -e "usage: \x1b[92msource\x1b[0m $0 [vars-file] [--clean] [--dest=dir]"
  echo
  echo "vars-file is a text file that lists the secrets to extract from the key vault along"
  echo "with how to write them to the local environment."
  echo "If not specified, the vars-file defaults to 'secret-vars.txt'"
  echo
  echo "This loops through the lines in the specified secrets file and loads the secrets into"
  echo "environment variables, files or into a secrets.auto.tfvars file"
  echo 
  echo "The format of the file is:"
  echo 
  echo "terraform_variable  [nameInVault]"
  echo
  echo "terraform_variable is the variable to set"
  echo
  echo "If 'nameInVault' is skipped, this will get the secret from 'terraform_variable'"
  echo
  echo "These variables and the secrets are written to 'secrets.auto.tfvars' file in the ./terraform directory."
  echo
  echo "If 'ENV ' preceeds the variable, then the terraform_variable is exported to the environment"
  echo "eg: ENV someVar:someVarInVault"
  echo "results in export someVar=secret"
  echo
  echo "If 'FILE ' preceeds the variable then the secret is downloaded to a file named after the"
  echo "terraform_variable."
  echo "eg: FILE produser_rsa:prodSSHSecret"
  echo "results in a file called 'produser_rsa' in the current directory with the secret as its content.'"
  echo 
  echo "Note about file secrets. Be sure to upload them using az cli instead of setting in the portal."
  echo "The portal messes up newlines"
  echo
  echo "az keyvault secret set --name XYZ --vault-name NucleusIaCVaultDev --file whatever"
  echo 
  echo "If any key cannot be found, this will fail and delete all the files it created as well as unset"
  echo "all the environment variables."
  echo
  echo "--clean will use the secrets file to remove all the files and environment variables that were written/set"
  echo
  echo "--dest=dir will change the default destination directory from 'terraform' to 'dir'. If 'dir' is blank, the"
  echo "           'secrets.auto.tfvars' is written to the current directory"
  echo
  echo -e "\x1b[93mNote the \x1b[92msource \x1b[93mprefix - that is the only way the environment variable is saved.\x1b[0m"
  if [ $0 == $BASH_SOURCE ]; then
    exit 1
  else
    return
  fi
fi

if [ $0 == $BASH_SOURCE ]; then
  echo -e "\x1b[91mYou must 'source' this for it to work\x1b[0m"
  echo -e "usage: \x1b[92msource\x1b[0m $0 vars-file [environment]"
  exit 1
fi

deploymentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
TF_VAR_deploymentDir=$deploymentDir
export deploymentDir
export TF_VAR_deploymentDir

clean=0
silent=0
inputfile="secret-vars.txt"
destDir=terraform

for var in "$@"; do
  if [[ $var =~ ^--clean ]]; then
    clean=1
  elif [[ $var =~ ^--dest= ]]; then
    IFS='=' read -ra PART_ARG <<< "$var"
    destDir="${PART_ARG[1]}"
  elif [[ $var =~ ^--silent ]]; then
    silent=1
  else
    inputfile=$var
  fi
done

if [[ ! -f $inputfile ]]; then
  echo "Cannot find secrets file: $inputfile"
  return 1
fi

function get_secret_name {
  if [ $# == 1 ] || [ -z $2 ]; then
    echo "$1"
  else
    echo "$2"
  fi
}

function get_secret {
  if [ -z "$vaultName" ]; then
    echo "No Vault Name is specified in secret-vars.txt"
    return 1
  fi

  echo "$(az keyvault secret show --name "$1" --vault-name $vaultName --query value -o tsv)"
}

# state variables
secretVarsFile=secrets.auto.tfvars
if [ ! -z "$destDir" ]; then
  secretVarsFile="$destDir/$secretVarsFile"
  mkdir -p "$destDir"
fi

lineFailed=
exports=()
reports=()
envToUnsetOnFail=()
filesToRemoveOnFail=("$secretVarsFile")


echo "Extracting secrets..."

function download_secret {
  secretFileDir="secretfiles"
  rm -f "$secretFileDir/$2"
  if [ $? != 0 ]; then
    lineFailed="Failed to remove file '$2' to hold secret '$1'"
    return
  fi

  if [ $clean == 1 ]; then
    return
  fi

  mkdir -p "$secretFileDir"

  filesToRemoveOnFail+=("$secretFileDir/$2")

  if [ -z "$vaultName" ]; then
    echo "No Vault Name is specified in secret-vars.txt"
    return 1
  fi

  az keyvault secret download --name "$1" --vault-name $vaultName --file "$secretFileDir/$2"
  if [ $? != 0 ]; then
    lineFailed="Failed to lookup '$1' and/or write to '$secretFileDir/$2'"
  fi

  chmod 600 "$secretFileDir/$2"
}

function parse_line {
  if [ -z $1 ]; then
    return 
  fi

  doWhat="var"
  
  if [[ ${1:0:1} == "#" ]]; then
    return
  elif [[ $1 == "ENV" ]]; then
    doWhat="ENV"
  elif [[ $1 == "FILE" ]]; then
    doWhat="FILE"
  elif [[ $1 == "SET" ]]; then
    export "$2=$3"
    envToUnsetOnFail+=("$2")
    return
  elif [[ $1 != "TF" ]]; then
    lineFailed="An unknown operation prefix of $1 was specified."
    clean=1
    return
  fi

  shift
  secretVar=$1
  secretName=$(get_secret_name $secretVar "$2")

  # TODO use download instead of show for file secrets
  if [[ $doWhat == "FILE" ]]; then
    download_secret "$secretName" "$secretVar"
    return
  elif [ $clean == 0 ]; then
    secret=$(get_secret "$secretName")
    if [ -z "$secret" ]; then
      lineFailed="Failed to lookup '$secretName' in vault from line '$*'"
      return
    fi
  fi

  if [[ $doWhat == "ENV" ]]; then
    if [ $clean == 0 ]; then
      exports+=("$secretVar=$secret")
    fi
    envToUnsetOnFail+=("$secretVar")
  elif [ $clean == 0 ]; then
    echo "$secretVar = \"$secret\"" >> $secretVarsFile
  fi
}

echo "" > $secretVarsFile

while IFS= read -r line
do
  # No quotes on purpose - $line is split into two arguements when there is a space
  parse_line $line

  if [ ! -z "$lineFailed" ]; then
    break
  fi
# don't even bother letting comment and blank lines in
done < <(grep -v "^\s*#" "$inputfile" | grep -v "^\s*$")

# catch the last line
if [ -z "$lineFailed" ]; then
  parse_line $line
fi

if [ ! -z "$lineFailed" ]; then
  echo "Failed: $lineFailed"
  clean=1
fi

if [ $clean == 1 ]; then
  echo "Cleaning secrets from environment and files"
  for f in ${filesToRemoveOnFail[@]}
  do
    rm -f $f
  done
  for e in ${envToUnsetOnFail[@]}
  do
    unset $e
  done

  if [ ! -z "$lineFailed" ]; then
    return 1
  fi
  
  return
fi

for exprt in ${exports[@]}
do
  export $exprt
done

readarray -t sortedFiles < <(for a in "${filesToRemoveOnFail[@]}"; do echo "$a"; done | sort)
readarray -t sortedVars < <(for a in "${envToUnsetOnFail[@]}"; do echo "$a"; done | sort)

if [ $silent != 1 ]; then
  echo
  echo FILES:
  for file in ${sortedFiles[@]}
  do
    echo "./$file"
  done
  echo

  echo ENVIRONMENT VARIABLES:
  for env in ${sortedVars[@]}
  do
    printf "%-25s %s\n" "$env" "$(eval "echo \${$env}")"
  done
  echo
fi
