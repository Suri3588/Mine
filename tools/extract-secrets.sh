#!/usr/bin/env bash

inputfile=$1

if [ $0 == $BASH_SOURCE ]; then
  echo -e "\x1b[91mYou must 'source' this for it to work\x1b[0m"
  echo -e "usage: \x1b[92msource\x1b[0m $0 vars-file [environment]"
  exit 1
fi

if [ -z $inputfile ]; then
  echo -e "\x1b[91mYou must provide a valid secrets file as the input parameter\x1b[0m"
  return 1
fi


if [[ ! -f $inputfile ]]; then
  echo -e "\x1b[91mCannot find secrets file: $inputfile\x1b[0m"
  return 1
fi

deploymentDir=$(dirname $inputfile)

pushd $deploymentDir > /dev/null
source ./extract-secrets.sh $@
popd > /dev/null
