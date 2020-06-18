#!/bin/bash

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
pushd $scriptDir

kubectl get namespaces nucleus
if [ $? -ne 0 ]; then
  echo "nucleus namespace not defined"
  echo "run the shared deploy script"
  exit 1
fi

kubectl -n nucleus apply -f background-processor-config.yaml
kubectl -n nucleus apply -f background-processor.yaml

popd
