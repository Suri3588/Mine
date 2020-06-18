#!/bin/bash

# Restarts the elasticsearch pods.

kubectl scale deployment -n logging elasticsearch-client --replicas=0

for (( i=0; i<$esMasterNodeCount; i++ ))
do
	kubectl scale deployment -n logging elasticsearch-master-$i --replicas=0
done

for (( i=0; i<$esDataNodeCount; i++ ))
do
	kubectl scale StatefulSet -n logging elasticsearch-data --replicas=0
done

kubectl scale StatefulSet -n logging elasticsearch-data --replicas=$esDataNodeCount

for (( i=0; i<$esMasterNodeCount; i++ ))
do
	kubectl scale deployment -n logging elasticsearch-master-$i --replicas=1
done

kubectl scale deployment -n logging elasticsearch-client --replicas=1

