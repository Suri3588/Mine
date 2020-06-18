#!/bin/bash

if [ "$1" == "--ids-only" ]; then
	IDS_ONLY="--ids-only"
else
	IDS_ONLY=""
fi

$(dirname "$0")/listSavedObjects.sh $IDS_ONLY "visualization"

