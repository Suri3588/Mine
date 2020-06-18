#!/bin/bash

# Deletes kibana and the elasticsearch pods. Run 'deploy.sh' afterwards to repair.

kubectl delete -f kibana.yaml
kubectl delete -f elasticsearch-60-deployment-client.yml

for (( i=0; i<$esMasterNodeCount; i++ ))
do
    kubectl delete -f elasticsearch-40-deployment-master-$i.yml
done

kubectl delete -f elasticsearch-30-statefulset-data.yml

kubectl --namespace=logging delete secrets elasticsearch
kubectl --namespace=logging delete secrets kibana-config

