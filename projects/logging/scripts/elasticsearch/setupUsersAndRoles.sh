#!/bin/bash

# Sets up the elasticsearch users and roles, as defined in the elasticsearch-users.csv file.

source $(dirname "$0")/commonFunctions.sh

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

checkForSecretVar "projects directory" "$projectsDir"
checkForSecretVar "beats password" "$beatsPassword"
checkForSecretVar "kibana admin password" "$kibanaAdminPassword"
checkForSecretVar "elasticsearch read-only password" "$elasticsearchReadOnlyPassword"

# Create temp dir and cleanup handler
TMP_DIR="/dev/shm/usersAndRoles.$$"

cleanup() {
	rm -rf $TMP_DIR
	stopElasticsearchTunnel
}

trap cleanup EXIT
mkdir "$TMP_DIR"
startElasticsearchTunnel

# Read-Only Role
cat <<EOT >> "$TMP_DIR/read_only_role"
{
  "cluster" : [ ],
  "indices" : [
    {
      "names" : [
        "filebeat-*",
        "metricbeat-*",
        "packetbeat-*",
        "winlogbeat-*",
        "heartbeat-*",
        ".kibana*"
      ],
      "privileges" : [
        "read"
      ],
      "allow_restricted_indices" : false
    }
  ],
  "applications" : [
    {
      "application" : "kibana-.kibana",
      "privileges" : [
        "all"
      ],
      "resources" : [
        "*"
      ]
    }
  ],
  "run_as" : [ ],
  "metadata" : { },
  "transient_metadata" : {
    "enabled" : true
  }
}
EOT

# Beats Writer Role
cat <<EOT >> "$TMP_DIR/beats_writer_role"
{
  "cluster": ["manage_index_templates","monitor","manage_ingest_pipelines"], 
  "indices": [
    {
      "names": [ "filebeat-*", "metricbeat-*", "packetbeat-*", "heartbeat-*", "winlogbeat-*" ], 
      "privileges": ["write","create_index"]
    }
  ]
}
EOT

createUser() {
	local USERNAME="$1"
	local PASSWORD="$2"
	local FULL_NAME="$3"
	local ROLE="$4"

cat <<EOT > "$TMP_DIR/user"
{
  "password" : "$PASSWORD",
  "roles" : [ "$ROLE" ],
  "full_name" : "$FULL_NAME"
}
EOT

	putFileToElasticSearch "/_security/user/$USERNAME" "$TMP_DIR/user" | checkCreated

	if [ $? -ne 0 ]; then
		echo "Error: Unable to create '$USERNAME' user." 1>&2
		exit 3
	fi

	echo "Successfully created '$USERNAME' user."
}

# Create 'read_only' role.
putFileToElasticSearch "/_xpack/security/role/read_only" "$TMP_DIR/read_only_role" | checkCreated

if [ $? -ne 0 ]; then
	echo "Error: Unable to create 'read_only' role." 1>&2
	exit 2
fi

echo "Successfully created 'read_only' role."

# Create 'beats_writer' role.
putFileToElasticSearch "/_xpack/security/role/beats_writer" "$TMP_DIR/beats_writer_role" | checkCreated

if [ $? -ne 0 ]; then
	echo "Error: Unable to create 'beats_writer' role." 1>&2
	exit 2
fi

echo "Successfully created 'beats_writer' role."

# Create the users.
if ! [ -f "$deploymentDir/$projectsDir/logging/elasticsearch-users.csv" ] ; then
	echo "Error: Could not find elasticsearch-users.csv." 1>&2
	exit 2
fi

cat "$deploymentDir/$projectsDir/logging/elasticsearch-users.csv" | sed "s/BEATS_PASSWORD/$beatsPassword/;s/KIBANA_ADMIN_PASSWORD/$kibanaAdminPassword/;s/ELASTICSEARCH_READ_ONLY_PASSWORD/$elasticsearchReadOnlyPassword/" | while read oneLine
do
	# Trim line
	oneLine=`echo "$oneLine" | sed 's/^ *//;s/ *$//'`
	
	if [ -n "$oneLine" ]; then
		USERNAME=`echo "$oneLine" | sed 's/,.*//'`
		PASSWORD=`echo "$oneLine" | sed 's/[^,]*,//;s/,.*//'`
		FULL_NAME=`echo "$oneLine" | sed 's/[^,]*,//;s/[^,]*,//;s/,.*//'`
		ROLE=`echo "$oneLine" | sed 's/.*,//'`
		
		createUser "$USERNAME" "$PASSWORD" "$FULL_NAME" "$ROLE"
	fi
done
