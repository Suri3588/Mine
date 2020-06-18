#!/bin/bash

# Renders and applies the elasticserach ingress rules.

RENDER_ONLY=false

if [ "$1" == "--render-only" ]; then
	RENDER_ONLY=true
fi

checkForVar() {
	local DESCRIPTION="$1"
    local VAR_VALUE="$2"

    if [ -z "$VAR_VALUE" ]; then
        echo "No $DESCRIPTION specified secret-vars.txt" 1>&2
        exit 1
    fi
}

printApiKey() {
	local RESOURCE_GROUP="$1"
	local EXIT_CODE

	az keyvault secret show --name "beatsElasticsearchToken-$RESOURCE_GROUP" --vault-name $vaultName --query value -o tsv 2> /dev/null
}

renderElasticsearchIngress() {
	local BASIC_AUTH=`echo -n "beats_client:$beatsPassword" | base64`
	local LINE
	local GROUP_NAME
	local API_TOKEN
	
	cat "$LOGGING_DIR/elasticsearch-70-ingress.yml" | sed "s/REPLACE_ME_BEATS_AUTH/$BASIC_AUTH/" > "$TMP_DIR/elasticsearch-70-ingress.yml"
	grep "REPLACE_ME_API_TOKEN_" "$LOGGING_DIR/elasticsearch-70-ingress.yml" > "$TMP_DIR/tokenLines"
	while read LINE
	do
		GROUP_NAME=`echo "$LINE" | sed 's/.*REPLACE_ME_API_TOKEN_//;s/".*//'`
		API_TOKEN=`printApiKey "$GROUP_NAME"`

		if [ $? -ne 0 ]; then
			echo "Error: Unable to get 'beatsElasticsearchToken-$GROUP_NAME' secret from '$vaultName' vault." 1>&2
			exit 1
		fi

		sed -i "s/REPLACE_ME_API_TOKEN_$GROUP_NAME\")/$API_TOKEN\")/" "$TMP_DIR/elasticsearch-70-ingress.yml"
	done < "$TMP_DIR/tokenLines"
}

TMP_DIR="/dev/shm/applyElasticsearchIngress.$$"
trap "rm -rf $TMP_DIR" EXIT
mkdir $TMP_DIR

if [ -z "$deploymentDir" ]; then
	echo "The deploymentDir is not set, run extract-secrets.sh"
	exit 1
fi

checkForVar "vault name" "$vaultName"
checkForVar "beats password" "$beatsPassword"

LOGGING_DIR="$deploymentDir/$projectsDir/logging"

renderElasticsearchIngress

if [ $RENDER_ONLY == false ] ; then
	echo "Applying elasticsearch ingress rules..."
	echo
	cat "$TMP_DIR/elasticsearch-70-ingress.yml"
	echo
	kubectl apply -f "$TMP_DIR/elasticsearch-70-ingress.yml"
else
	cat "$TMP_DIR/elasticsearch-70-ingress.yml"
fi
