#!/bin/bash

resGroup=$1
shortName=$2
remoteVnetId=$3

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
if [ "$scriptDir" == /Users/* ]; then
  nucleusHome="$(cd $scriptDir/../../../../../../.. >/dev/null & pwd)"
else
  nucleusHome="/Nucleus"
fi

az network vnet peering create -g $resGroup -n to-$shortName --vnet-name resgrp-vnet --remote-vnet-id $remoteVnetId --allow-vnet-access