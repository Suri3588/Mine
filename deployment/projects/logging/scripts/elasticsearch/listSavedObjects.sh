#!/bin/bash

if [ "$1" == "--ids-only" ]; then
	IDS_ONLY=true
	shift
else
	IDS_ONLY=false
fi

OBJECT_TYPE="$1"

source $(dirname "$0")/commonFunctions.sh

if [ -z "$OBJECT_TYPE" ]; then
	logError "Usage: ./listSavedObjects.sh [--ids-only] OBJECT_TYPE"
	exit 1
fi

TMP_DIR="/dev/shm/list.$$"
trap "rm -rf $TMP_DIR" EXIT
mkdir "$TMP_DIR"
TMP_FILE="$TMP_DIR/unsorted"

executeCommandOnKibanaPod curl -s -L -u "$ES_USER:$ES_PASSWORD" -X GET "http://kibana-logging:5601/api/saved_objects/_find?type=$OBJECT_TYPE&fields=id&fields=title" | jq '.saved_objects' | jq -c '.[]' | while read OBJECT
do
	ID=`echo "$OBJECT" | jq -r '.id'`

	if [ "$IDS_ONLY" == true ]; then
		echo "$ID" >> "$TMP_DIR/unsorted"
	else
		TITLE=`echo "$OBJECT" | jq '.attributes.title'`
		echo "$ID	$TITLE" >> "$TMP_DIR/unsorted"
	fi
done

if [ "$IDS_ONLY" == true ]; then
	sort "$TMP_DIR/unsorted"
else
	echo "ID	TITLE" > "$TMP_DIR/sorted"
	echo "--	-----" >> "$TMP_DIR/sorted"
	cat "$TMP_DIR/unsorted" | sort >> "$TMP_DIR/sorted"
	cat "$TMP_DIR/sorted" | column -ts $'\t'
fi

