#!/bin/bash

# Loads the elasticsearch ingestion piplines.

EXIT_CODE_UNABLE_TO_INSTALL_PIPELINE=3

source $(dirname "$0")/commonFunctions.sh

PIPELINES_DIR=$(dirname "$0")/pipelines

trap stopElasticsearchTunnel EXIT
startElasticsearchTunnel

installPipeline() {
	local PIPELINE_NAME="$1"
	local PIPELINE_FILENAME="$2"
	
	putFileToElasticSearch "/_ingest/pipeline/$PIPELINE_NAME" "$PIPELINES_DIR/$PIPELINE_FILENAME" | grep -q '{\"acknowledged\":true}'
	
	if [ $? -ne 0 ]; then
		echo "Error: Unable to install $PIPELINE_NAME pipeline." 1>&2
		exit $EXIT_CODE_UNABLE_TO_INSTALL_PIPELINE
	fi
}

installPipeline "nucleus-pl-mongodb" "pipeline-mongodb.json"
installPipeline "nucleus-pl-nucleus-app" "pipeline-nucleus-app.json"
installPipeline "nucleus-pl-pm2-status" "pipeline-pm2-status.json"

#installPipeline "nucleus-pl-nginx-access" "pipeline-nginx-access.json"
#installPipeline "nucleus-pl-nginx-error" "pipeline-nginx-error.json"
#installPipeline "nucleus-pl-syslog" "pipeline-syslog.json"
#installPipeline "nucleus-pl-system-auth" "pipeline-system-auth.json"
#installPipeline "nucleus-pl-pm2" "pipeline-pm2.json"
#installPipeline "nucleus-pl-ossec" "pipeline-ossec.json"
#installPipeline "nucleus-pl-offline-check" "pipeline-offline-check.json"

