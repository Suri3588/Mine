#!/bin/bash

source $(dirname "$0")/common-library.sh

SKIP_JUMP_BOX_SHUTDOWN=false

if [ "$1" == "--skip-jump-box-shutdown" ]; then
	SKIP_JUMP_BOX_SHUTDOWN=true
	shift
fi

if [ -z "$1" ]; then
	echo "Usage: linkToSharedServices.sh RESOURCE_GROUP_NAME_TO_LINK <PASSTHRU_IP_TO_LINK_TO>" 1>&2
	exit 1
fi

if [ -n "$2" ]; then
	PASSTHRU_IP="$2"
fi 

if [ -z "$deploymentDir" ]; then
	echo "The deploymentDir is not set, run extract-secrets.sh"
	exit 1
fi

checkForVar "projects directory" "$projectsDir"
checkForVar "secrets directory" "$secretsDir"
checkForVar "resource group" "$resourceGroup"
checkForVar "vault name" "$vaultName"
checkForVar "beats password" "$beatsPassword"

# This is the resource group that we want to link to this shared services deployment, not
# the name of the shared services resource group.
RESOURCE_GROUP_TO_LINK="$1"

LOGGING_DIR="$deploymentDir/$projectsDir/logging"
PROMETHEUS_CONFIG_NAME="prometheus.yaml"
PROMETHEUS_CONFIG_PATH="$LOGGING_DIR/$PROMETHEUS_CONFIG_NAME"
PROMETHEUS_ADDON="$LOGGING_DIR/prometheusAddon.yaml"
SHARED_SERVICES_PASSTHRU_IP="10.1.6.5"
SSH_KEY_FILE="$deploymentDir/$secretsDir/ssh_rsa"

TMP_DIR="/dev/shm/linkToSharedServices.$$"
trap "rm -rf $TMP_DIR" EXIT
mkdir $TMP_DIR

addIngressForDeployment() {
	local RESOURCE_GROUP="$1"

	if ! grep -q "REPLACE_ME_API_TOKEN_$RESOURCE_GROUP\"" "$LOGGING_DIR/elasticsearch-70-ingress.yml" ; then
		local INSERTION_POINT=`grep -n "Begin Token Check" "$LOGGING_DIR/elasticsearch-70-ingress.yml" | sed 's/:.*//'`
		local LINE_COUNT=`wc -l "$LOGGING_DIR/elasticsearch-70-ingress.yml" | sed 's/ .*//'`
		local REMAINING_LINE_COUNT=$(( $LINE_COUNT - $INSERTION_POINT ))
			
		head -$INSERTION_POINT "$LOGGING_DIR/elasticsearch-70-ingress.yml" > "$TMP_DIR/newElasticsearchIngressConfig"
		echo "      if (\$http_beatstoken = \"REPLACE_ME_API_TOKEN_$RESOURCE_GROUP\") {  # ResourceGroup: $RESOURCE_GROUP" >> "$TMP_DIR/newElasticsearchIngressConfig"
		echo '          set $isValidBeatsToken "true";' >> "$TMP_DIR/newElasticsearchIngressConfig"
		echo "      }" >> "$TMP_DIR/newElasticsearchIngressConfig"
		tail -$REMAINING_LINE_COUNT "$LOGGING_DIR/elasticsearch-70-ingress.yml" >> "$TMP_DIR/newElasticsearchIngressConfig"
	
		cat "$TMP_DIR/newElasticsearchIngressConfig" > "$LOGGING_DIR/elasticsearch-70-ingress.yml"
	fi
}

createBeatsToken() {
	local RESOURCE_GROUP="$1"
	local BEATS_TOKEN=`az keyvault secret show --name "beatsElasticsearchToken-$RESOURCE_GROUP" --vault-name $vaultName --query value -o tsv 2> /dev/null`
	local EXIT_CODE=0

	if [ -z "$BEATS_TOKEN" ] ; then
		echo ""
		echo "could not find beatsElasticsearchToken-$RESOURCE_GROUP in vaultName. Please ensure it's there and relink again."
		exit 1
	fi

	echo "$BEATS_TOKEN"
	exit $EXIT_CODE
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

if [ -z "$PASSTHRU_IP" ]; then
	echo -n "Determining $RESOURCE_GROUP_TO_LINK passthru box private IP..."
	PASSTHRU_IP=`az vm show -g $RESOURCE_GROUP_TO_LINK -n passthru -d --query privateIps -otsv`

	if [ -z "$PASSTHRU_IP" ]; then
		echo
		echo "Unable to determine the passthru private IP." 1>&2
		exit 4
	fi
fi

echo " $PASSTHRU_IP"

if ! [ -f $SSH_KEY_FILE ]; then
	echo "Error: Unable to find SSH key file $SSH_KEY_FILE" 1>&2
	exit 2
fi

# Idempotency check
grep -q "Begin Deployment $RESOURCE_GROUP_TO_LINK$" $PROMETHEUS_CONFIG_PATH

if [ $? -ne 0 ]; then
	INSERTION_POINT=`grep -n "Deployment Jobs" $PROMETHEUS_CONFIG_PATH | sed 's/:.*//'`
	LINE_COUNT=`wc -l $PROMETHEUS_CONFIG_PATH | sed 's/ .*//'`
	REMAINING_LINE_COUNT=$(( $LINE_COUNT - $INSERTION_POINT ))

	echo "Creating config..."

	head -$INSERTION_POINT $PROMETHEUS_CONFIG_PATH > "$TMP_DIR/newConfig"
	sed "s/REPLACE_ME_RESOURCE_GROUP_NAME/$RESOURCE_GROUP_TO_LINK/g" $PROMETHEUS_ADDON >> "$TMP_DIR/newConfig"
	tail -$REMAINING_LINE_COUNT $PROMETHEUS_CONFIG_PATH >> "$TMP_DIR/newConfig"

	#vimdiff "$TMP_DIR/newConfig" $PROMETHEUS_CONFIG_PATH

	cp "$TMP_DIR/newConfig" $PROMETHEUS_CONFIG_PATH

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

if ! grep -q "^$PASSTHRU_IP $RESOURCE_GROUP_TO_LINK" "$deploymentDir/$projectsDir/passthru/passthru/hosts.j2" ; then
	echo "Updating local 'hosts.j2' template."
	echo "$PASSTHRU_IP $RESOURCE_GROUP_TO_LINK" >> "$deploymentDir/$projectsDir/passthru/passthru/hosts.j2"

	echo "Adding shared services hosts entry to $RESOURCE_GROUP_TO_LINK passthru host..."

	ssh -o UserKnownHostsFile=/dev/null -o 'StrictHostKeyChecking no' -i $SSH_KEY_FILE -o ProxyCommand="ssh -o UserKnownHostsFile=/dev/null -o 'StrictHostKeyChecking no' -i $SSH_KEY_FILE -W %h:%p nucleus@$JUMPBOX_IP" nucleus@$SHARED_SERVICES_PASSTHRU_IP -- "echo '$PASSTHRU_IP $RESOURCE_GROUP_TO_LINK' | sudo tee -a /etc/hosts"
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
fi

echo "Creating beats token..."
BEATS_TOKEN=`createBeatsToken "$RESOURCE_GROUP_TO_LINK"`
checkExitCode $? "Unable to create 'beatsElasticsearchToken-$RESOURCE_GROUP_TO_LINK' secret in '$vaultName' vault."
echo "BEATS_TOKEN: $BEATS_TOKEN"

echo "Updating nginx ingress configuration..."
addIngressForDeployment "$RESOURCE_GROUP_TO_LINK"
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

