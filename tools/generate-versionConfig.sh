#!/bin/bash

while getopts "m:b:v:d:" arg; do
  case $arg in
    m) MonitorUrl=$OPTARG;;
    b) BeatsElasticsearchToken=$OPTARG;;
    v) Version=$OPTARG;;
    d) Directory=$OPTARG;;
  esac
done

if [ -z $MonitorUrl ]; then
  echo "-m MonitorUrl is required"
  exit 1
fi

if [ -z $BeatsElasticsearchToken ]; then
  echo "-b BeatsElasticsearchToken is required"
  exit 1
fi

if [ -z $Version ]; then
  echo "-v Version is required"
  exit 1
fi

if [ -z $Directory ]; then
  echo "-d Directory is required"
  exit 1
fi

# Generate versionConfig.json
FilePath=$Directory/Versions/$Version/NucleusEdgeServer/configs/versionConfig-$Version.json
cat > $FilePath << EOF
{
  "version": "$Version",
  "monitorUrl": "$MonitorUrl",
  "beatsElasticsearchToken": "$BeatsElasticsearchToken"
}
EOF

# Update installConfiguration.json
FilePath=$Directory/EdgeServerSetup/installConfiguration.json
read -d '' info << EOF
{
  "monitorUrl": "$MonitorUrl",
  "beatsElasticsearchToken": "$BeatsElasticsearchToken"
}
EOF
newInfo=`jq ". |= . + $info" $FilePath`
echo $newInfo | jq '.' > $FilePath
