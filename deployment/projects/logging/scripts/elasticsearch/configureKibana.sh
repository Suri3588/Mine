#!/bin/bash

# Used to setup the initial kibana configuration.

TMP_FILE="/dev/shm/component.$$.json"
trap "rm -f $TMP_FILE /tmp/filebeatSetupConfig.yml" EXIT

source $(dirname "$0")/commonFunctions.sh

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

checkForSecretVar "projects directory" "$projectsDir"

trap stopElasticsearchTunnel EXIT
startElasticsearchTunnel

EXIT_CODE_CANNOT_DETERMINE_KIBANA_VERSION=2
EXIT_CODE_UNABLE_TO_SET_DEFAULT_INDEX=3
EXIT_CODE_UNABLE_TO_QUERY_KIBANA_COMPONENT=4
EXIT_CODE_UNABLE_TO_UPLOAD_KIBANA_COMPONENT=5
EXIT_CODE_UNABLE_TO_UPLOAD_ELASTICSEARCH_TEMPLATE=6
EXIT_CODE_UNABLE_TO_CREATE_INDEX_PATTERN=7
EXIT_CODE_UNABLE_TO_SETUP_DASHBOARD=8
EXIT_CODE_UNABLE_TO_IMPORT_FILEBEAT_MODULES=9

#CREDENTIALS=`printCurlAuthenticationCredentials`

uploadComponent() {
	local COMPONENT="$1"
	local NAME="$2"
	local UPLOAD_FILE="$3"
	
	local ESCAPED_NAME=`jsonEscape "$NAME"`
	local ID_NAME=`echo "$NAME" | sed 's/ /-/g;s/&//g;s/--*/-/g;s/(//g;s/)//g'`
	
	# First, check to see if it exists.
	 SERVER_REPONSE=`postStringToElasticSearch "/.kibana/doc/_search" "{\"size\": 1, \"query\": {\"match_phrase\": {\"$COMPONENT.title\": $ESCAPED_NAME}}}"`
	
	if [ $? -ne 0 ]; then
		echo "Unable to query kibana for overview $COMPONENT." 1>&2
		exit $EXIT_CODE_UNABLE_TO_QUERY_KIBANA_COMPONENT
	fi

	if echo "$SERVER_REPONSE" | noSearchHits ; then
		echo -n "{\"type\": \"$COMPONENT\",\"$COMPONENT\":" > $TMP_FILE
		cat "$UPLOAD_FILE" | sed 's/"id":"[^"]*",//' >> $TMP_FILE
		echo -n "}" >> $TMP_FILE
		
		putFileToElasticSearch "/.kibana/_doc/$COMPONENT:$ID_NAME" "$TMP_FILE" | checkSuccess
		
		if [ $? -ne 0 ]; then
			echo "Unable to upload kibana $COMPONENT." 1>&2
			exit $EXIT_CODE_UNABLE_TO_UPLOAD_KIBANA_COMPONENT
		else
			echo "Successfully uploaded kibana $COMPONENT."
		fi
	else
		echo "Existing $COMPONENT found, no need to upload."
	fi
}

uploadDashboard() {
	local NAME="$1"
	local UPLOAD_FILE="$2"

	echo "Uploading the $NAME Dashboard..."
	uploadComponent "dashboard" "$NAME" "$deploymentDir/$projectsDir/logging/kibana-dashboard-json/$UPLOAD_FILE"
}

uploadVisualization() {
	local NAME="$1"
	local UPLOAD_FILE="$2"
	
	echo "Uploading the $NAME Visualization..."
	uploadComponent "visualization" "$NAME" "$deploymentDir/$projectsDir/logging/kibana-visualizations-json/$UPLOAD_FILE"
}

uploadTemplate() {
	local BEATNAME="$1"
	
	local TEMPLATE_NAME=`cat "{{monitoring_dir}}/templates/$BEATNAME.template.json" | grep "$BEATNAME-" | sed 's/-\*"//;s/.*"//'`
	
	# First, check to see if it exists.
	curl -s /-X GET "http://{{monitor_host_name}}:9200/_template/$BEATNAME* $CREDENTIALS" | grep "^{}$" > /dev/null

	if [ $? -eq 0 ]; then
		echo "Uploading the $BEATNAME Template..."
		curl -s -H 'Content-Type: application/json' $CREDENTIALS -XPUT "http://{{monitor_host_name}}:9200/_template/$TEMPLATE_NAME" -d@"{{monitoring_dir}}/templates/$BEATNAME.template.json"  | checkAcknowledged

		if [ $? -ne 0 ]; then
			echo "Unable to upload $BEATNAME template." 1>&2
			exit $EXIT_CODE_UNABLE_TO_UPLOAD_ELASTICSEARCH_TEMPLATE
		else
			echo "Successfully uploaded $BEATNAME template."
		fi
	else
		echo "Existing template found, no need to upload."
	fi
}

createIndexPattern() {
	local PATTERN="$1"
	
	curl -s -XPUT "http://{{monitor_host_name}}:9200/.kibana/doc/index-pattern:$PATTERN" -H "Content-Type: application/json" $CREDENTIALS -d "{\"type\" : \"index-pattern\",\"index-pattern\" : {\"title\": \"$PATTERN\",\"timeFieldName\": \"@timestamp\"}}" | checkSuccess
	
	if [ $? -ne 0 ]; then
		echo "Unable to create $PATTERN index pattern." 1>&2
		exit $EXIT_CODE_UNABLE_TO_CREATE_INDEX_PATTERN
	else
		echo "Successfully created $PATTERN index pattern."
	fi
}

setupDashboard() {
	local BEATS_NAME="$1"
	
	local RETRIES_LEFT=3
	
	while [ $RETRIES_LEFT -gt 0 ]; do
		/usr/bin/$BEATS_NAME setup --dashboards -E "setup.kibana.host=http://{{ monitor_host_name }}:5601" -E output.elasticsearch.username=$ES_USER -E output.elasticsearch.password=$ES_PASSWORD

		if [ $? -ne 0 ] ; then
			if [ $RETRIES_LEFT -eq 1 ] ; then
				echo "Unable to setup $BEATS_NAME dashboard." 1>&2
				exit $EXIT_CODE_UNABLE_TO_SETUP_DASHBOARD
			else
				echo "Trouble setting up $BEATS_NAME dashboard, trying again in 60 seconds." 1>&2
				sleep 60
			fi
		else
			break
		fi
		
		RETRIES_LEFT=$(( $RETRIES_LEFT - 1 ))
	done
}

echo "Configuring kibana..."

# NOTE: A lot of this is commented out, as it's copied from the nucleus 2.0 repo.
#       But much of this may return, so I'm not ready to strip it out yet.

#KIBANA_VERSION=`curl -s -L http://{{monitor_host_name}}:9200/ $CREDENTIALS | grep "\"number\"" | sed 's/.*: "//;s/".*//'`

#if [ -z "$KIBANA_VERSION" ] ; then
#	echo "Could not determine kibana version." 1>&2
#	exit $EXIT_CODE_CANNOT_DETERMINE_KIBANA_VERSION
#fi

#echo "Seting the default index for Kibana (v$KIBANA_VERSION)..."

EXIT_CODE=1
REMAINING_TRIES=3

#while [ $EXIT_CODE -ne 0 ] && [ $REMAINING_TRIES -gt 0 ]; do
#	curl -s -X POST -H "Content-Type: application/json" -H "kbn-xsrf: true" $CREDENTIALS -d '{"value":"{{ default_kibana_index }}"}' http://{{ monitor_host_name }}:5601/api/kibana/settings/defaultIndex | grep -q defaultIndex
#	EXIT_CODE=$?
#	REMAINING_TRIES=$(( $REMAINING_TRIES - 1 ))

#	if [ $EXIT_CODE -ne 0 ]; then
#		echo "Unable to set kibana default index ($EXIT_CODE), trying again (retries remaining: $REMAINING_TRIES)." 1>&2
#	fi
#done

#if [ $EXIT_CODE -ne 0 ]; then
#	exit $EXIT_CODE_UNABLE_TO_SET_DEFAULT_INDEX
#else
#	echo "Successfully set the kibana default index."
#fi

# Setup beats dashboards.
#setupDashboard "filebeat"
#setupDashboard "metricbeat"
#setupDashboard "packetbeat"
#setupDashboard "heartbeat"

$(dirname "$0")/importAllKibanaSavedObjects.sh

# Setup Winglogbeat Template
#uploadTemplate "winlogbeat"

# Set up the filebeat modules
#service filebeat stop

#cat <<EOT > /tmp/filebeatSetupConfig.yml
#output.elasticsearch:
#  hosts: ["{{monitor_host_name}}:9200"]
#EOT

#appendBeatsCredentials "/tmp/filebeatSetupConfig.yml"

#cat <<EOT >> /tmp/filebeatSetupConfig.yml
#setup.kibana:
#  host: "{{monitor_host_name}}:5601"
#EOT

#timeout --signal=kill 1m /usr/share/filebeat/bin/filebeat -once -c /tmp/filebeatSetupConfig.yml -path.config /etc/filebeat -path.home /usr/share/filebeat -path.logs /var/log/filebeat -path.data /var/lib/filebeat -e -modules=system,nginx -setup

#if [ $? -ne 137 ]; then
#	echo "Unable to import filebeat modules." 1>&2
#	exit $EXIT_CODE_UNABLE_TO_IMPORT_FILEBEAT_MODULES
#fi

#service filebeat start

# Clean up unneeded visualizations.
#{{monitoring_dir}}/bin/cleanupKibana.sh

echo "Successfully configured kibana."
