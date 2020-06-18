#!/bin/bash

# A library of common functions, shared among the elasticsearch scripts, in this directory.

ES_SERVER="localhost"
ES_USER="elastic"
ES_PASSWORD="$elasticsearchPassword"
ES_SECURITY_CERTS_ENABLED=false

# TODO: This is copied over from Nucleus 2.0 and hasn't yet been updated for shared services.
CLIENT_CERTIFICATE="/usr/local/nucleus/monitoring/certs/nucleus-monitoring-client-certs.pem"
CLIENT_KEY="/usr/local/nucleus/monitoring/certs/nucleus-monitoring-client-key.pem"

if [ $ES_SECURITY_CERTS_ENABLED == true ] ; then
	PROTOCOL="https"
	SECURITY_PARAMS="--certificate=$CLIENT_CERTIFICATE --private-key=$CLIENT_KEY --user=$ES_USER --password=$ES_PASSWORD"
else
	PROTOCOL="http"
	SECURITY_PARAMS="--user=$ES_USER --password=$ES_PASSWORD"
fi

logError() {
	local MESSAGE="$1"

	if test -t 2 ; then
		echo -e "\033[01;31mError:\033[00m $MESSAGE" 1>&2
	else
		echo "Error: $MESSAGE" 1>&2
	fi
}

logWarning() {
	local MESSAGE="$1"

	if test -t 2 ; then
		echo -e "\033[01;33mWarning:\033[00m $MESSAGE" 1>&2
	else
		echo "Warning: $MESSAGE" 1>&2
	fi
}

logSuccess() {
	local MESSAGE="$1"

	if test -t 1 ; then
		echo -e "\033[01;32mSuccess:\033[00m $MESSAGE"
	else
		echo "Success: $MESSAGE"
	fi
}

checkExitCode() {
	local EXIT_CODE=$1
	local ERROR_MSG="$2"

	if [ $EXIT_CODE -ne 0 ]; then
		logError "$ERROR_MSG"
		exit $EXIT_CODE
	fi
}

checkForSecretVar() {
	local DESCRIPTION="$1"
    local VAR_VALUE="$2"

    if [ -z "$VAR_VALUE" ]; then
        echo "No $DESCRIPTION specified secret-vars.txt" 1>&2
        exit 1
    fi
}

postStringToElasticSearch() {
	local LOCATION="$1"
	local POST_DATA="$2"
	local USERNAME="$3"		# Optional
	local PASSWORD="$4"		# Optional
	
	if [ -z "$USERNAME" ] ; then
		USERNAME="$ES_USER"
	fi
	
	if [ -z "$PASSWORD" ] ; then
		PASSWORD="$ES_PASSWORD"
	fi
	
	wget -q -O - $SECURITY_PARAMS "$PROTOCOL://$ES_SERVER:9200$LOCATION" --header="Content-Type: application/json" --post-data="$POST_DATA"
}

postFileToElasticSearch() {
	local LOCATION="$1"
	local POST_FILE="$2"
	local USERNAME="$3"		# Optional
	local PASSWORD="$4"		# Optional
	
	if [ -z "$USERNAME" ] ; then
		USERNAME="$ES_USER"
	fi
	
	if [ -z "$PASSWORD" ] ; then
		PASSWORD="$ES_PASSWORD"
	fi
	
	wget -q -O - $SECURITY_PARAMS "$PROTOCOL://$ES_SERVER:9200$LOCATION" --header="Content-Type: application/json" --post-file="$POST_FILE"
}

putFileToElasticSearch() {
	local LOCATION="$1"
	local POST_FILE="$2"
	local USERNAME="$3"		# Optional
	local PASSWORD="$4"		# Optional

	if [ -z "$USERNAME" ] ; then
		USERNAME="$ES_USER"
	fi
	
	if [ -z "$PASSWORD" ] ; then
		PASSWORD="$ES_PASSWORD"
	fi
	
	if [ $ES_SECURITY_CERTS_ENABLED == true ] ; then
		curl -s -H 'Content-Type: application/json' -u "$USERNAME:$PASSWORD" --cert $CLIENT_CERTIFICATE --key $CLIENT_KEY -k -X PUT "$PROTOCOL://$ES_SERVER:9200$LOCATION" -T "$POST_FILE"
	else
		curl -s -H 'Content-Type: application/json' -u "$USERNAME:$PASSWORD" -X PUT "$PROTOCOL://$ES_SERVER:9200$LOCATION" -T "$POST_FILE"
	fi
}

printCurlAuthenticationCredentials() {
	if [ $ES_SECURITY_CERTS_ENABLED == true ] ; then
		echo "-u $ES_USER:$ES_PASSWORD --cert $CLIENT_CERTIFICATE --key $CLIENT_KEY -k"
	else
		echo "-u $ES_USER:$ES_PASSWORD"
	fi
}

appendBeatsCredentials() {
	local FILENAME="$1"
	
	if [ $ES_SECURITY_CERTS_ENABLED == true ] ; then
		echo "  username: $ES_USER" >> "$FILENAME"
		echo "  password: $ES_PASSWORD" >> "$FILENAME"
		echo "  ssl.certificate: \"$CLIENT_CERTIFICATE\"" >> "$FILENAME"
		echo "  ssl.key: \"$CLIENT_KEY\"" >> "$FILENAME"
		echo "  ssl.certificate_authorities: [\"/usr/local/nucleus/monitoring/certs/nucleus.ca.crt\"]" >> "$FILENAME"
	else
		echo "  username: $ES_USER" >> "$FILENAME"
		echo "  password: $ES_PASSWORD" >> "$FILENAME"
	fi
}

getFromElasticSearch() {
	local LOCATION="$1"

	wget -q -O - $SECURITY_PARAMS "$PROTOCOL://$ES_SERVER:9200$LOCATION"
}

deleteFromElasticSearch() {
	local LOCATION="$1"

	wget -q -O - $SECURITY_PARAMS --method=DELETE "$PROTOCOL://$ES_SERVER:9200$LOCATION"
}

printIdForVisualizationTitle() {
	local TITLE="$1"
	$(dirname "$0")/dumpRawComponent.sh "visualization" "$TITLE" | grep '"_id":"visualization:' | sed 's/.*"_id":"visualization://;s/",.*//'
}

# Strips the devlivery envelop and leaves only the relevant source.
stripEnvelope() {
	sed 's/.*"_source"://;s/....$//'
}

# Strips the ES 6.0 component wrapper.
stripComponent() {
	local COMPONENT="$1"
	sed "s/^{\"$COMPONENT\"://"
}

# Prints a URL-compatible escaped string.
urlEscape() {
	echo "$1" | sed 's/ /%20/g;s/=/%3d/g;s/&/%26/g'
}

# Creates a JSON escaped string, with start and end quotes.
jsonEscape() {
    printf '%s' "$1" | python -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# Checks certain elasticsearch commands for success.
checkDeleted() {
	grep -q '"result":"deleted"'
}

# Checks certain elasticsearch commands for success.
checkSuccess() {
	grep -q '"successful":[1-9]'
}

# Checks certain elasticsearch commands for success.
checkAcknowledged() {
	grep -q '"acknowledged":true'
}

# Checks certain elasticsearch commands for creation.
checkCreated() {
	grep -q '"created"'
}

# Checks to see that there are no matching search results.
noSearchHits() {
	grep -q '"hits":{"total":{"value":0,'
}

startElasticsearchTunnel() {
	# Let's first verify we're on a shared-services
	kubectl port-forward -n logging services/elasticsearch-client 9200:9200 > /dev/null &

	local KUBE_PID=`ps -ef | grep kubectl | grep port-forward | grep elasticsearch-client | awk '{print $2}'`

	if [ -z "$KUBE_PID" ]; then
		logError "Unable to start port-forwarder to logging-services/elasticsearch-client."
		exit 1
	fi

	sleep 3
}

stopElasticsearchTunnel() {
	local KUBE_PID=`ps -ef | grep kubectl | grep port-forward | grep elasticsearch-client | awk '{print $2}'`
	if [ -n "$KUBE_PID" ]; then
		kill "$KUBE_PID" > /dev/null
	fi
}

executeCommandOnKibanaPod() {
	local COMMAND="$@"

	local POD_NAME=`kubectl get pods --all-namespaces | grep kibana-logging | awk '{print $2}'`

	if [ -z "$POD_NAME" ]; then
		logError "Unable to determine 'kibana-logging' pod name."
		exit 1
	fi
	
	kubectl exec -n logging $POD_NAME -- $COMMAND
}

# Make sure the elasticsearch password was extracted from secret-vars.txt
checkForSecretVar "elasticsearch password" "$elasticsearchPassword"

