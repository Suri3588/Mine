#!/bin/bash

# Dumps the kibana dashboard, with the passed in ID, to standard out.

DASHBOARD_ID="$1"

source $(dirname "$0")/commonFunctions.sh

if [ -z "$DASHBOARD_ID" ]; then
	logError "Usage: ./showDashboard.sh DASHBOARD_ID"
	echo 1>&2
	echo "Use one of the following IDs:" 1>&2
	$(dirname "$0")/listDashboards.sh
	exit 1
fi

$(dirname "$0")/showSavedObject.sh "dashboard" "$DASHBOARD_ID"
EXIT_CODE=$?
echo
exit $EXIT_CODE

