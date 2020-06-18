#!/bin/bash

# Dumps the kibana index pattern, with the passed in ID, to standard out.

INDEX_PATTERN_ID="$1"

source $(dirname "$0")/commonFunctions.sh

if [ -z "$INDEX_PATTERN_ID" ]; then
	logError "Usage: ./showIndexPattern.sh INDEX_PATTERN_ID"
	echo 1>&2
	echo "Use one of the following IDs:" 1>&2
	$(dirname "$0")/listIndexPatterns.sh
	exit 1
fi

$(dirname "$0")/showSavedObject.sh "index-pattern" "$INDEX_PATTERN_ID"
EXIT_CODE=$?
echo
exit $EXIT_CODE

