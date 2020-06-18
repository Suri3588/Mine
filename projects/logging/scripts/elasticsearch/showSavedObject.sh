#!/bin/bash

# Dumps the kibana saved-object, with the passed in object type and ID, to standard out.

COMPONENT="$1"
ID="$2"

# Create temp dir
TMP_DIR="/dev/shm/exportSavedObject.$$"
trap "rm -rf $TMP_DIR" EXIT
mkdir "$TMP_DIR"

source $(dirname "$0")/commonFunctions.sh

printUsage() {
	echo "Usage: ./showSavedObject.sh dashboard|visualization|index-pattern OBJECT_ID" 1>&2
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

executeCommandOnKibanaPod curl -s -L -u "$ES_USER:$ES_PASSWORD" -X GET "http://kibana-logging:5601/api/saved_objects/$COMPONENT/$ID" > $TMP_DIR/commandOutput

cat "$TMP_DIR/commandOutput" | jq '.references' > $TMP_DIR/references

if [ "`cat $TMP_DIR/references`" != "null" ]; then
	# Warn about any external references, not included in this dump.
	while read OBJECT
	do
		TYPE=`echo "$OBJECT" | jq -r '.type'`
		ID=`echo "$OBJECT" | jq -r '.id'`
		echo "$TYPE $ID" >> $TMP_DIR/referenceList
	done < <( cat $TMP_DIR/references | jq -c '.[]' )

	if [ -f $TMP_DIR/referenceList ] ; then
		while read LINE
		do
			TYPE="${LINE%% *}"
			ID="${LINE#* }"
			logWarning "This object references an '$TYPE' with an ID of '$ID'. Make sure that has been exported too."
		done < <( sort -u $TMP_DIR/referenceList )
	fi
fi

cat "$TMP_DIR/commandOutput"

