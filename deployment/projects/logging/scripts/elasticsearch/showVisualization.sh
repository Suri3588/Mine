#!/bin/bash

# Dumps the kibana visualization, with the passed in ID, to standard out.

VISUALIZATION_ID="$1"

source $(dirname "$0")/commonFunctions.sh

if [ -z "$VISUALIZATION_ID" ]; then
	logError "Usage: ./showVisualization.sh VISUALIZATION_ID"
	echo 1>&2
	echo "Use one of the following IDs:" 1>&2
	$(dirname "$0")/listVisualizations.sh
	exit 1
fi

$(dirname "$0")/showSavedObject.sh "visualization" "$VISUALIZATION_ID"
EXIT_CODE=$?
echo
exit $EXIT_CODE

