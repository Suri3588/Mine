#!/bin/bash

# This will attempt to save all kibana dashboards, visualizations and dashboards.

SCRIPT_DIR=$(dirname "$0")

source $(dirname "$0")/commonFunctions.sh

importAll() {
	local FILENAME

	while read FILENAME
	do
		echo "Importing $FILENAME..."
		$SCRIPT_DIR/importKibanaSavedObject.sh "$FILENAME"
		
		if [ $? -ne 0 ]; then
			logError "Failure to import object, terminating."
			exit 1
		fi
	done < <( ls *ndjson )
}

cd "$SCRIPT_DIR"
SCRIPT_DIR=`pwd`
echo "Importing index patterns..."
cd ../../kibana-index-patterns-json
importAll

echo "Importing visualizations..."
cd ../kibana-visualizations-json
importAll

echo "Importing dashboards..."
cd ../kibana-dashboards-json
importAll

