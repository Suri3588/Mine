#!/usr/bin/env bash

source $(dirname "$0")/common-library.sh

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

checkForVar "resource group" "$resourceGroup"
checkForVar "terraform directory" "$terraformDir"
checkForVar "modules directory" "$modulesDir"
checkForVar "projects directory" "$projectsDir"
checkForVar "secrets directory" "$secretsDir"
checkForVar "DNS prefix" "$dnsPrefix"
checkForVar "DNS zone" "$dnsZone"
checkForVar "deploy domain" "$deployDomain"
checkForVar "elasticsearch data node count" "$esDataNodeCount"
checkForVar "elasticsearch master node count" "$esMasterNodeCount"
checkForVar "elasticsearch client node count" "$esClientNodeCount"
checkForVar "elasticsearch data disk size" "$esDataDiskSize"
checkForVar "elasticsearch retention days" "$esRetentionDays"
checkForVar "elastalert primary alert e-mail" "$esPrimaryAlertEmail"
checkForVar "grafana admin password" "$grafanaAdminPassword"
checkForVar "elasticsearch password" "$elasticsearchPassword"
checkForVar "elasticsearch read-only password" "$elasticsearchReadOnlyPassword"
checkForVar "kibana password" "$kibanaPassword"
checkForVar "kibana admin password" "$kibanaAdminPassword"
checkForVar "beats password" "$beatsPassword"
checkForVar "isSharedService flag" "$isSharedService"

branchName=$(git rev-parse --abbrev-ref HEAD)
resourceGroupLowered=$(echo "$resourceGroup" | tr '[:upper:]' '[:lower:]')

echo "{"
echo "  \"resourceGroup\": \"$resourceGroup\","
echo "  \"resourceGroupLowered\": \"$resourceGroupLowered\","
echo "  \"subscriptionId\": \"$subscriptionId\","
echo "  \"terraformStorageAccount\": \"$terraformStorageAccount\","
echo "  \"dnsPrefix\": \"$dnsPrefix\","
echo "  \"dnsZone\": \"$dnsZone\","
echo "  \"deployDomain\": \"$deployDomain\","
echo "  \"dockerRegistry\": \"$dockerRegistry\","
echo "  \"internalIngressIp\": \"10.1.6.6\","
echo "  \"externalIngressIp\": \"1.2.3.4\","
echo "  \"k8sServiceHost\": \""$resourceGroup-dns-XXXXXXX"\","
echo "  \"esDataNodeCount\": \"$esDataNodeCount\","
echo "  \"esMasterNodeCount\": \"$esMasterNodeCount\","
echo "  \"esClientNodeCount\": \"$esClientNodeCount\","
echo "  \"esPrimaryAlertEmail\": \"$esPrimaryAlertEmail\","
echo "  \"grafanaAdminPassword\": \"$grafanaAdminPassword\","
echo "  \"elasticsearchPassword\": \"$elasticsearchPassword\","
echo "  \"elasticsearchReadOnlyPassword\": \"$elasticsearchReadOnlyPassword\","
echo "  \"kibanaPassword\": \"$kibanaPassword\","
echo "  \"kibanaAdminPassword\": \"$kibanaAdminPassword\","
echo "  \"branchName\": \"$branchName\","
echo "  \"jenkinsServicePrincipal\": \"$jenkinsServicePrincipal\","
echo "  \"jenkinsBuildType\": \"$jenkinsBuildType\","
echo "  \"beatsPassword\": \"$beatsPassword\","
echo "  \"esDataDiskSize\": \"$esDataDiskSize\","
echo "  \"esRetentionDays\": \"$esRetentionDays\","
echo "  \"aksAadClientId\": \"$aksAadClientId\","
echo "  \"aksAadServerId\": \"$aksAadServerId\","
echo "  \"aksAadServerSecret\": \"$aksAadServerSecret\","
echo "  \"aksAadTenantId\": \"$aksAadTenantId\","
echo "  \"akcPrincipal\": \"$akcPrincipal\","
echo "  \"akcPrincipalPassword\": \"$akcPrincipalPassword\","
echo "  \"fluentdStorageAccount\": \"$fluentdStorageAccount\","
echo "  \"fluentdStorageAccountKey\": \"$fluentdStorageAccountKey\","
echo "  \"isSharedService\": \"$isSharedService\","
echo "  \"frameAncestors\": \"\","
echo "  \"deploymentDir\": \"$deploymentDir\","
echo "  \"secretsDir\": \"$secretsDir\","
echo "  \"modulesDir\": \"$modulesDir\","
echo "  \"projectsDir\": \"$projectsDir\""
echo "}"

exit 0
