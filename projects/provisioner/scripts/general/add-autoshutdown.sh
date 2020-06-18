#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ $# -ne 1 ]; then
  echo "usage: add-autoshutdown.sh  resource-group-name"
  exit 1
fi

rg=$1
source $SCRIPT_DIR/login-azure.sh

rgStatus=$(az group exists -n $rg)
if [[ "$rgStatus" != "true" ]]; then
  echo "Resource group $rg does not exist"
  exit 1
fi

az group update -n $rg --set tags.AutoShutdownSchedule="19:00->6:00, Saturday, Sunday"

az logout
