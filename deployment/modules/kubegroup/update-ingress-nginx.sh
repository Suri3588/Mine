#!/usr/bin/env bash

if [ -z "$resourceGroup" ]; then
    echo "No resource group specified in secret-vars.txt"
    exit 1
fi

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$projectsDir" ]; then
    echo "No projects directory specified in secret-vars.txt"
    exit 1
fi

if [ -z "$dnsPrefix" ]; then
    echo "No DNS Prefix specified in secret-vars.txt"
    exit 1
fi

externalIngressIp=$(az network public-ip show --resource-group $resourceGroup-ip --name $dnsPrefix-public-ip --query "{address: ipAddress}" 2> /dev/null | jq -r .address )
if [ -z "$externalIngressIp" ]; then
    echo "Unable to get the external ingress IP"
    exit 1
fi

k8sServiceHost=$(az aks show -g $resourceGroup -n $resourceGroup-aks 2> /dev/null | jq -r .fqdn)
if [ -z "$k8sServiceHost" ]; then
    echo "Unable to get the FQDN of the kubernetes cluster"
    exit 1
fi

echo "Found Public IP: $externalIngressIp"
echo "Found cluster FQDN: $k8sServiceHost"

# update the loadBalancerIP
var=$(grep "loadBalancerIP:" $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml)
if [ -z "$var" ]; then
    echo "Unable to locate loadBalancer IP entry in $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml"
    exit 1
fi

sed -i "s/$var/  loadBalancerIP: $externalIngressIp/g" $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml
if [ $? -ne 0 ]; then
    echo "An error occurred updating the loadBalancerIP in $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml"
    exit 1
fi

# verify that the change exists 1 time in the file
var=$(grep "loadBalancerIP: $externalIngressIp" $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml | wc -l)
if [ "$var" != "1" ]; then
    echo "An error occurred verifying the loadBalancerIP update in $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml"
    exit 1
fi

# update the FQDN for the cluster
old=$(grep "$resourceGroup-dns-" $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml | head -1 | awk '{print $2}')
if [ -z "$old" ]; then
    echo "Unable to locate FQDN entry in $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml"
    exit 1
fi

sed -i "s/$old/$k8sServiceHost/g" $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml
if [ $? -ne 0 ]; then
    echo "An error occurred updating Kubernetes cluster FQDN in $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml"
    exit 1
fi

# verify that the change exists 4 times in the file
var=$(grep "$k8sServiceHost" $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml | wc -l)
if [ "$var" != "4" ]; then
    echo "An error occurred verifying the Kubernetes cluster FQDN update in $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml"
    exit 1
fi

echo "The file: $deploymentDir/$projectsDir/baseline/ingress-nginx/ingress-nginx.yaml has been updated"
exit 0
