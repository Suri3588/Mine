#!/bin/bash

while getopts "f:d:p:" arg; do
  case $arg in
    f) FilePath=$OPTARG;;
    d) Directory=$OPTARG;;
    p) Password=$OPTARG;;
  esac
done

if [ -z $Password ]; then
  echo "'-p Password' is required"
  exit 1
fi

function SignFile() {
  filePath=$1
  password=$2
  sigFile=$filePath.sig
  echo filePath:$filePath
  gpg --pinentry-mode loopback --yes --passphrase=$password --output $sigFile --detach-sig $filePath
}

if [ -z $FilePath ]; then
  export -f SignFile
  find $Directory -type f | xargs -I {} bash -c 'SignFile "$@"' _ {} $Password
else
  SignFile $FilePath $Password
fi
