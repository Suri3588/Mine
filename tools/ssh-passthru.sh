#!/bin/bash

# SSH to the passthru box, for a deployment. This will work for any deployment, using
# the same $vaultName environment variable, from your secret-vars.txt file (ie. you
# don't need to be in any particular branch).
#
# You don't even need to be in a provisioner, so long as you have 'az' installed and
# you have your $vaultName variable set.
#
# NOTE: This script will not currently start and stop the jumpbox for you. To be
#       implemented, in the future.

DEPLOYMENT="$1"

if [ -z "$DEPLOYMENT" ]; then
	echo "Usage: ssh-passthru DEPLOYMENT" 1>&2
	exit 1
fi

source $(dirname "$0")/common-library.sh
checkForVar "vault name" "$vaultName"

TMP_DIR="/dev/shm/ssh-passthru-$$"
trap "rm -rf $TMP_DIR" exit
mkdir "$TMP_DIR"

az keyvault secret download --name sshPrivateKey-$DEPLOYMENT --vault-name $vaultName --file "$TMP_DIR/ssh-rsa"

if [ $? -ne 0 ]; then
	echo "Error: Unable to download sshPrivateKey-$DEPLOYMENT secret." 1>&2
	exit 2
fi

chmod 600 "$TMP_DIR/ssh-rsa"

JUMPBOX_IP=`az network public-ip show --resource-group $DEPLOYMENT --name jump-public-ip --query "{address: ipAddress}" 2>/dev/null | jq -r .address`
PASSTHRU_IP=`az vm show -g $DEPLOYMENT -n passthru -d --query privateIps -otsv`

ssh -o UserKnownHostsFile=/dev/null -o 'StrictHostKeyChecking no' -i $TMP_DIR/ssh-rsa -o ProxyCommand="ssh -o UserKnownHostsFile=/dev/null -o 'StrictHostKeyChecking no' -i $TMP_DIR/ssh-rsa -W %h:%p nucleus@$JUMPBOX_IP" nucleus@$PASSTHRU_IP

