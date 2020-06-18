#!/bin/bash

# List all of the elasticsearch indices.

source $(dirname "$0")/commonFunctions.sh

trap stopElasticsearchTunnel EXIT
startElasticsearchTunnel

# Return all elasticsearch pipeline names.
getFromElasticSearch "/_aliases?pretty" | grep '^  "' | sed 's/^ *"//;s/".*//' | sort -u

