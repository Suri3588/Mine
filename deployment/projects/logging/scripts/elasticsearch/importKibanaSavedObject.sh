#!/bin/bash

# Imports a visualization, dashboard or index-pattern, into kibana. Requires an ndjson file.

SAVED_OBJECT_PATH="$1"
OUT_PATH="/dev/shm/object.$$.ndjson"

source $(dirname "$0")/commonFunctions.sh

if ! [ -f "$SAVED_OBJECT_PATH" ]; then
	logError "Unable to find '$SAVED_OBJECT_PATH'."
	exit 1
fi

cleanup() {
	kubectl exec -n logging `kubectl get pods --all-namespaces | grep kibana-logging | awk '{print $2}'` -- rm $OUT_PATH
}

trap cleanup EXIT

kubectl cp "$SAVED_OBJECT_PATH" -n logging `kubectl get pods --all-namespaces | grep kibana-logging | awk '{print $2}'`:$OUT_PATH

if [ $? -ne 0 ]; then
	logError "Unable to copy $SAVED_OBJECT_PATH to kibana-logging pod."
	exit 1
fi

executeCommandOnKibanaPod curl -s -L -u "$ES_USER:$ES_PASSWORD" -X POST "http://kibana-logging:5601/api/saved_objects/_import?overwrite=true" -H kbn-xsrf:true --form file=@$OUT_PATH | grep -q '{"success":true,"successCount":1}'

if [ $? -eq 0 ]; then
	logSuccess "Object '$SAVED_OBJECT_PATH' imported."
else
	logError "Unable to import '$SAVED_OBJECT_PATH'."
fi

