#!/bin/bash

while getopts "v:d:" arg; do
  case $arg in
    v) Version=$OPTARG;;
    d) Directory=$OPTARG;;
  esac
done

if [ -z $Version ]; then
  echo "-v Version is required"
  exit 1
fi

if [ -z $Directory ]; then
  echo "-d Directory is required"
  exit 1
fi

VersionConfigFilePath=$Directory/Versions/$Version/NucleusEdgeServer/configs/versionConfig-$Version.json
echo VersionConfigPath:$VersionConfigFilePath

ManifestFilePath=$Directory/Versions/$Version/manifest.json 
echo ManifestFilePath:$ManifestFilePath

ImportPublicKeyFilePath=$Directory/Versions/$Version/configs/import-public-$Version.key
ImportFingerprintFilePath=$Directory/Versions/$Version/configs/import-fingerprint-$Version.txt

function GetBase64Filehash() {
  hash=`openssl dgst -md5 -binary $1 | base64`
  echo $hash
}

function appendVersionConfig() {
  md5hash=$(GetBase64Filehash $VersionConfigFilePath)
  read -d '' versionConfig << EOF 
  {
    "name": "versionConfig-$Version.json",
    "refname": "versionConfig.json",
    "location": "/NucleusEdgeServer/configs",
    "md5": "$md5hash"
  }
EOF
  param=".applications[0].configs |= . + [ $versionConfig ]"
  result=`jq "$param" $ManifestFilePath`
  echo $result
}

# append versionConfig info
manifest=$(appendVersionConfig)

# update import public.key and fingerprint md5
md5hashPublicKey=$(GetBase64Filehash $ImportPublicKeyFilePath)
md5hashFingerprint=$(GetBase64Filehash $ImportFingerprintFilePath)
param=".configs[0].md5 = \"$md5hashFingerprint\" | .configs[1].md5 =\"$md5hashPublicKey\""
echo $manifest | jq "$param" > $ManifestFilePath
