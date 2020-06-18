#!/bin/bash

if [ $# -ne 3 ]; then
  echo "usage: argv[0] <ip-mask> <db-password> <db-name>"
  exit 1
fi

mask=$1
port=$2
dpass=$3
dbname=$4

encode=$(echo -n "mongodb://application:${3}@${1}.10:${2},${1}.11:${2},${1}.12:${2}/${4}?replicaSet=rs-${4}&readPreference=primaryPreferred&w=majority&autoReconnect=true" | base64 | tr -d '\n' )

echo "apiVersion: v1" > secrets.yaml
echo "kind: Secret" >> secrets.yaml
echo "metadata:" >> secrets.yaml
echo "  name: db-url" >> secrets.yaml
echo "type: Opaque" >> secrets.yaml
echo "data:" >> secrets.yaml
echo "  mongourl: $encode" >> secrets.yaml
