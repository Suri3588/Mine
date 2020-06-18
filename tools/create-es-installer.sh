#!/bin/bash

while getopts "p:k:m:b:v:d:" arg; do
  case $arg in
    p) GpgPasswordEnc64=$OPTARG;;
    k) GPGKeyEnc64=$OPTARG;;
    m) MonitorUrl=$OPTARG;;
    b) BeatsElasticsearchToken=$OPTARG;;
    v) Version=$OPTARG;;
    d) Directory=$OPTARG;;
  esac
done

if [ -z $GpgPasswordEnc64 ]; then
  echo "-p GpgPasswordEnc64 is required"
  exit 1
fi

if [ -z $GPGKeyEnc64 ]; then
  echo "-k GPGKeyEnc64 is required"
  exit 1
fi

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

TOOLS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

$TOOLS_DIR/generate-versionConfig.sh -v $Version -m $MonitorUrl -b $BeatsElasticsearchToken -d $Directory

Password=`echo $GpgPasswordEnc64 | base64 -d`
echo $GPGKeyEnc64 | base64 -d | gpg --pinentry-mode loopback --yes --passphrase=$Password --import 

# replace public.key and public.key.finterprint, and PublicKeyInfo.json
fp=`echo $(gpg -k) | awk '{print $7}'`
uid=`echo $(gpg -k | grep uid)`
publicKeyPath=$Directory/EdgeServerSetup/public.key
fingerprintPath=$publicKeyPath.fingerprint
importPath=$Directory/Versions/$Version/configs/
gpg --yes --batch --output $publicKeyPath --export EdgeServer@nucleushealth.io
echo $fp > $fingerprintPath
cp $publicKeyPath $importPath/import-public-$Version.key
cp $fingerprintPath $importPath/import-fingerprint-$Version.txt
cat > $Directory/PublicKeyInfo.json << EOF
{
  "supportedKeys": [
    "${fp:16}"
  ],
  "rsaKeyID": "${fp:16}",
  "KeySigner": "${uid:4}"
}
EOF

# remove existing signature file
find $Directory -name "*.sig" | xargs rm -f

# sign all files
$TOOLS_DIR/sign-files.sh -p $Password -d $Directory

$TOOLS_DIR/update-manifest.sh -d $Directory -v $Version
