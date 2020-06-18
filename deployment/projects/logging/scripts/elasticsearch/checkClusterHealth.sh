#!/bin/bash

# Reports on the health of the elasticsearch cluster.

source $(dirname "$0")/commonFunctions.sh

TMP_FILE=/dev/shm/clusterHealth.$$

cleanup() {
	rm -f $TMP_FILE
	stopElasticsearchTunnel
}

trap cleanup EXIT
startElasticsearchTunnel

NUMBER_OF_EXPECTED_NODES="$1"

getFromElasticSearch '/_cluster/health?pretty' > $TMP_FILE

if [ $? -ne 0 ]; then
	echo "Could not connect to cluster." 1>&2
	exit 2
fi

STATUS=`grep '"status"' $TMP_FILE | sed 's/",//;s/.*"//'`

if [ "$STATUS" == "red" ]; then
	echo "Cluster status is 'red'." 1>&2
	exit 3
fi

NODE_COUNT=`grep '"number_of_nodes"' $TMP_FILE | sed 's/,//;s/.* //'`

if [ -n "$NUMBER_OF_EXPECTED_NODES" ]; then
	if [ $NODE_COUNT -ne $NUMBER_OF_EXPECTED_NODES ]; then
		echo "Only $NODE_COUNT of $NUMBER_OF_EXPECTED_NODES detected." 1>&2
		exit 4
	fi
fi

echo "Status is '$STATUS' with $NODE_COUNT nodes detected."
