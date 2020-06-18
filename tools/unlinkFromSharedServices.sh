#!/bin/bash

source $(dirname "$0")/common-library.sh

SKIP_JUMP_BOX_SHUTDOWN=false

if [ "$1" == "--skip-jump-box-shutdown" ]; then
	SKIP_JUMP_BOX_SHUTDOWN=true
	shift
fi

if [ -z "$1" ]; then
	echo "Usage: unlinkFromSharedServices.sh RESOURCE_GROUP_NAME_TO_LINK" 1>&2
	exit 1
fi

if [ -z "$deploymentDir" ]; then
	echo "The deploymentDir is not set, run extract-secrets.sh"
	exit 1
fi

checkForVar "projects directory" "$projectsDir"
checkForVar "secrets directory" "$secretsDir"
checkForVar "resource group" "$resourceGroup"
checkForVar "vault name" "$vaultName"

# This is the resource group that we want to unlink from this shared services deployment, not
# the name of the shared services resource group.
RESOURCE_GROUP_TO_LINK="$1"

LOGGING_DIR="$deploymentDir/$projectsDir/logging"
PROMETHEUS_CONFIG_NAME="prometheus.yaml"
PROMETHEUS_CONFIG_PATH="$LOGGING_DIR/$PROMETHEUS_CONFIG_NAME"
PROMETHEUS_ADDON="$LOGGING_DIR/prometheusAddon.yaml"
SHARED_SERVICES_PASSTHRU_IP="10.1.6.5"
SSH_KEY_FILE="$deploymentDir/$secretsDir/ssh_rsa"

TMP_DIR="/dev/shm/unlinkFromSharedServices.$$"
trap "rm -rf $TMP_DIR" EXIT
mkdir $TMP_DIR

removeIngressForDeployment() {
	local RESOURCE_GROUP="$1"

	if grep -q "REPLACE_ME_API_TOKEN_$RESOURCE_GROUP\"" "$LOGGING_DIR/elasticsearch-70-ingress.yml" ; then
		local MATCH_POINT=`grep -n "REPLACE_ME_API_TOKEN_$RESOURCE_GROUP\"" "$LOGGING_DIR/elasticsearch-70-ingress.yml" | sed 's/:.*//'`
		MATCH_POINT=$(( $MATCH_POINT - 1 ))
		local LINE_COUNT=`wc -l "$LOGGING_DIR/elasticsearch-70-ingress.yml" | sed 's/ .*//'`
		local REMAINING_LINE_COUNT=$(( $LINE_COUNT - $MATCH_POINT - 3 ))
		
		head -$MATCH_POINT "$LOGGING_DIR/elasticsearch-70-ingress.yml" > "$TMP_DIR/newElasticsearchIngressConfig"
		tail -$REMAINING_LINE_COUNT "$LOGGING_DIR/elasticsearch-70-ingress.yml" >> "$TMP_DIR/newElasticsearchIngressConfig"
	
		cat "$TMP_DIR/newElasticsearchIngressConfig" > "$LOGGING_DIR/elasticsearch-70-ingress.yml"
	fi
}

# Start the jump box
echo "Starting jump box..."
if ! az vm start -g $resourceGroup -n jump ; then
	echo "Unable to start the jump box." 1>&2
	exit 1
fi

echo -n "Determining $resourceGroup jump box public IP..."
JUMPBOX_IP=`az network public-ip show --resource-group $resourceGroup --name jump-public-ip --query "{address: ipAddress}" 2>/dev/null | jq -r .address`

if [ -z "$JUMPBOX_IP" ]; then
	echo
	echo "Unable to determine the jump box public IP." 1>&2
	exit 3
fi

echo " $JUMPBOX_IP"

if ! [ -f $SSH_KEY_FILE ]; then
	echo "Error: Unable to find SSH key file $SSH_KEY_FILE" 1>&2
	exit 2
fi

# Idempotency check
grep -q "Begin Deployment $RESOURCE_GROUP_TO_LINK$" $PROMETHEUS_CONFIG_PATH

if [ $? -eq 0 ]; then
	echo "Creating config..."

	sed -i "/^    # Begin Deployment $RESOURCE_GROUP_TO_LINK$/,/^    # End Deployment $RESOURCE_GROUP_TO_LINK$/d" $PROMETHEUS_CONFIG_PATH

	cd $LOGGING_DIR

	echo "Applying config..."
	KUBECONFIG=$deploymentDir/$secretsDir/k8s-conf 
	export KUBECONFIG
	kubectl config use-context "api-deployment-account-default-$resourceGroup-aks"

	kubectl apply -f $PROMETHEUS_CONFIG_NAME
	EXIT_CODE=$?

	if [ $EXIT_CODE -ne 0 ]; then
		echo "Error: Unable to apply prometheus config." 1>&2
		exit $EXIT_CODE
	fi

	echo "Rescaling prometheus deployment to pick up config changes..."

	kubectl scale deployment prometheus --replicas=0 -n logging
	EXIT_CODE=$?

	if [ $EXIT_CODE -ne 0 ]; then
		echo "Error: Unable to scale down prometheus deployment." 1>&2
		exit $EXIT_CODE
	fi

	kubectl scale deployment prometheus --replicas=1 -n logging
	EXIT_CODE=$?

	if [ $EXIT_CODE -ne 0 ]; then
		echo "Error: Unable to scale up prometheus deployment." 1>&2
		exit $EXIT_CODE
	fi
fi

echo "Remove shared services hosts entry to $RESOURCE_GROUP_TO_LINK passthru host..."

ssh -o UserKnownHostsFile=/dev/null -o 'StrictHostKeyChecking no' -i $SSH_KEY_FILE -o ProxyCommand="ssh -o UserKnownHostsFile=/dev/null -o 'StrictHostKeyChecking no' -i $SSH_KEY_FILE -W %h:%p nucleus@$JUMPBOX_IP" nucleus@$SHARED_SERVICES_PASSTHRU_IP -- "sudo sed -i '/ $RESOURCE_GROUP_TO_LINK$/d' /etc/hosts"
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
	echo "Error: Unable to update hosts file on shared services passthru machine." 1>&2
	exit $EXIT_CODE
fi

echo "Restarting dnsmasq service on shared services passthru host..."

ssh -o UserKnownHostsFile=/dev/null -o 'StrictHostKeyChecking no' -i $SSH_KEY_FILE -o ProxyCommand="ssh -o UserKnownHostsFile=/dev/null -o 'StrictHostKeyChecking no' -i $SSH_KEY_FILE -W %h:%p nucleus@$JUMPBOX_IP" nucleus@$SHARED_SERVICES_PASSTHRU_IP -- sudo systemctl restart dnsmasq
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
	echo "Error: Unable to restart dnsmasq service on shared services passthru host." 1>&2
	exit $EXIT_CODE
fi

if ! grep -q "^$PASSTHRU_IP $RESOURCE_GROUP_TO_LINK" "$deploymentDir/$projectsDir/passthru/passthru/hosts.j2" ; then
	echo "Updating local 'hosts.j2' template."
	sed -i "/ $RESOURCE_GROUP_TO_LINK$/d" "$deploymentDir/$projectsDir/passthru/passthru/hosts.j2"
fi

echo "Updating nginx ingress configuration..."
removeIngressForDeployment "$RESOURCE_GROUP_TO_LINK"
$LOGGING_DIR/applyElasticsearchIngress.sh

if [ "$SKIP_JUMP_BOX_SHUTDOWN" == "false" ]; then
	echo "Deallocating jumpbox..."
	az vm deallocate -g $resourceGroup -n jump
	if [ $? -ne 0 ]; then
		echo "An error has occurred deallocating jumpbox." 1>&2
		exit 1
	fi
fi

echo "Success: It may take a few minutes for prometheus to start scraping again."
echo "         Be sure to commit your changes, or passthru hosts updates will be reverted."

