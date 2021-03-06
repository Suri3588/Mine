#!/bin/bash

# Saves a kibana dashboard to the current git branch.

if [ "$1" == "--recurse" ] || [ "$1" == "-r" ]; then
	RECURSE="--recurse"
	shift
else
	RECURSE=""
fi

ID="$1"

source $(dirname "$0")/commonFunctions.sh

printUsage() {
	echo "Usage: ./saveDashboard.sh [--recurse] OBJECT_ID" 1>&2
	echo 1>&2
	echo "Use one of the following IDs:" 1>&2
	$(dirname "$0")/listDashboards.sh
	exit 1
}

if [ -z "$ID" ]; then
	logError "No ID specified."
	printUsage
fi


$(dirname "$0")/saveSavedObject.sh $RECURSE "dashboard" "$ID"

