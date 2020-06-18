#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo 'usage: $0 subnetId'
  exit 1
fi

let m=$1/32
let x=$m+2
let n=$1%32
let y=n*8
let yo=$y+6
let bes=$y+7
let yi=$y+3

echo "{"
echo "  \"vnetCidr\": \"10.$x.$y.0/21\","
echo "  \"classCPlus\": \"10.$x.$y\","
echo "  \"classCPlusOffset\": \"10.$x.$yo\","
echo "  \"internalIngressIp\": \"10.$x.$yi.110\"","
echo "  \"passthruIp\": \"10.$x.$bes.105\""
echo "}"
