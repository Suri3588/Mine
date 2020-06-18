#!/bin/bash

# Saves a kibana saved object to the local git branch. This script shouldn't
# be called directly. It's a helper script for the other save scripts.

if [ "$1" == "--recurse" ] || [ "$1" == "-r" ]; then
	RECURSE=true
	shift
else
	RECURSE=false
fi

COMPONENT="$1"
ID="$2"

source $(dirname "$0")/commonFunctions.sh

printUsage() {
	echo "Usage: ./saveSavedObject.sh [--recurse] dashboard|visualization|index-pattern OBJECT_ID" 1>&2
	exit 1
}

if [ -z "$COMPONENT" ]; then
	logError "No component specified."
	printUsage
fi

if [ -z "$ID" ]; then
	logError "No ID specified."
	printUsage
fi

BASE_DIR="/KNucleus-cs/projects/logging"
DEPLOYMENT_BASE_DIR="/KNucleus-cs/deployment/projects/logging"
TMP_DIR="/dev/shm/saveSavedObject.$$"

trap "rm -rf $TMP_DIR" EXIT
mkdir "$TMP_DIR"

# Strips a title of special characters, replace spaces with dashes, conver to lowercase.
printFileNameForTitle() {
	local TITLE="$1"
	BASE_NAME=`echo "$TITLE" | sed 's/ /-/g;s/\\*/star/g' | tr -cd '[:alnum:]-' | sed -r 's/-+/-/g' | tr '[:upper:]' '[:lower:]'`
	echo "$BASE_NAME.ndjson"
}

if ! [ -d "$BASE_DIR" ]; then
	logError "Could not find logging project to save to: $BASE_DIR"
	exit 1
fi

SAVE_SUB_DIR="kibana-$COMPONENT""s-json"
SAVE_DIR="$BASE_DIR/$SAVE_SUB_DIR"
DEPLOYMENT_SAVE_DIR="$DEPLOYMENT_BASE_DIR/$SAVE_SUB_DIR"

if ! [ -d "$SAVE_DIR" ]; then
	logError "Could not find the save directory: $SAVE_DIR"
	exit 2
fi

if [ "$COMPONENT" = "visualization" ]; then
	$(dirname "$0")/showVisualization.sh "$ID" > "$TMP_DIR/object" 2> "$TMP_DIR/warnings"
elif [ "$COMPONENT" = "dashboard" ]; then
	$(dirname "$0")/showDashboard.sh "$ID" > "$TMP_DIR/object" 2> "$TMP_DIR/warnings"
elif [ "$COMPONENT" = "index-pattern" ]; then
	$(dirname "$0")/showIndexPattern.sh "$ID" > "$TMP_DIR/object" 2> "$TMP_DIR/warnings"
fi

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
	logError "Unable to download $COMPONENT with id: $ID"
	exit $EXIT_CODE
fi

if [ "$RECURSE" == true ]; then
	# Scan the warning log for any external references and save those too.
	while read LINE
	do
		TYPE=`echo "$LINE" | sed "s/' with an ID of '.*//;s/.*'//"`
		ID=`echo "$LINE" | sed "s/.*' with an ID of '//;s/'. Make.*//"`
		$(dirname "$0")/saveSavedObject.sh "$TYPE" "$ID"
	done < "$TMP_DIR/warnings"
fi

TITLE=`cat "$TMP_DIR/object" | jq -r '.attributes.title'`
FILENAME=`printFileNameForTitle "$TITLE"`
cp "$TMP_DIR/object" "$SAVE_DIR/$FILENAME"

if [ -d "$DEPLOYMENT_BASE_DIR" ]; then
	# If there's a deployment directory, save it there too.
	if ! [ -d "$DEPLOYMENT_SAVE_DIR" ]; then
		mkdir "$DEPLOYMENT_SAVE_DIR"
	fi

	cp "$TMP_DIR/object" "$DEPLOYMENT_SAVE_DIR/$FILENAME"
fi

logSuccess "Saved $FILENAME in $SAVE_DIR."
