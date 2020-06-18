#!/usr/bin/env bash

if [ -z "$deploymentDir" ]; then
    echo "The deploymentDir is not set, run extract-secrets.sh"
    exit 1
fi

if [ -z "$resourceGroup" ]; then
    echo "No resourceGroup specified secret-vars.txt"
    exit 1
fi

if [ -z "$terraformDir" ]; then
    echo "No terraformDir specified in secret-vars.txt"
    exit 1
fi

if [ -z "$modulesDir" ]; then
    echo "No modulesDir specified in secret-vars.txt"
    exit 1
fi

if [ -z "$projectsDir" ]; then
    echo "No projectsDir specified in secret-vars.txt"
    exit 1
fi

if [ -z "$secretsDir" ]; then
    echo "No secretsDir specified in secret-vars.txt"
    exit 1
fi

if [ -z "$dnsPrefix" ]; then
    echo "No dnsPrefix specified secret-vars.txt"
    exit 1
fi

if [ -z "$deployDomain" ]; then
    echo "No deployDomain specified secret-vars.txt"
    exit 1
fi

if [ -z "$dockerRegistry" ]; then
    echo "No dockerRegistry specified secret-vars.txt"
    exit 1
fi

if [ -z "$isSharedService" ]; then
    echo "The isSharedService is not set, run extract-secrets.sh"
    exit 1
fi

# get the front end subnet
FES=$(az network vnet subnet show --resource-group $resourceGroup --name front-end-subnet --vnet-name $resourceGroup-network | jq -r .addressPrefix)
if [ -z "$FES" ]; then
    echo "Unable to find the virtual network $resourceGroup-network"
    exit 1
fi

IP_ONLY=`echo "$FES" | sed 's/\/.*//'`
IP4=`echo "$IP_ONLY" | sed 's/.*\.//'`
REMAINING=`echo "$IP_ONLY" | sed 's/\.[^.]*$//'`
IP3=`echo "$REMAINING" | sed 's/.*\.//'`
REMAINING=`echo "$REMAINING" | sed 's/\.[^.]*$//'`
IP2=`echo "$REMAINING" | sed 's/.*\.//'`
REMAINING=`echo "$REMAINING" | sed 's/\.[^.]*$//'`
IP1=`echo "$REMAINING" | sed 's/.*\.//'`

MINUS_SIX=$(( $IP3 - 6 ))
PLUS_ONE=$(( $IP3 + 1 ))
Y_PLUS_THREE=$(( $MINUS_SIX + 3 ))

mongo1=$(az vm show -g $resourceGroup -n mongo1 -d --query privateIps -otsv)
if [ -z "$mongo1" ]; then
    echo "Unable to get the IP address for mongo1"
    exit 1
fi

mongo2=$(az vm show -g $resourceGroup -n mongo2 -d --query privateIps -otsv)
if [ -z "$mongo2" ]; then
    echo "Unable to get the IP address for mongo2"
    exit 1
fi

mongo3=$(az vm show -g $resourceGroup -n mongo3 -d --query privateIps -otsv)
if [ -z "$mongo3" ]; then
    echo "Unable to get the IP address for mongo3"
    exit 1
fi

branchName=$(git rev-parse --abbrev-ref HEAD)
resourceGroupLowered=$(echo "$resourceGroup" | tr '[:upper:]' '[:lower:]')

echo "{"
echo "  \"resourceGroup\": \"$resourceGroup\","
echo "  \"resourceGroupLowered\": \"$resourceGroupLowered\","
echo "  \"subscriptionId\": \"$subscriptionId\","
echo "  \"terraformStorageAccount\": \"$terraformStorageAccount\","
echo "  \"classCPlus\": \"$IP1.$IP2.$MINUS_SIX\","
echo "  \"classCPlusOffset\": \"$IP1.$IP2.$IP3\","
echo "  \"passthruIp\": \"$IP1.$IP2.$PLUS_ONE.105\","
echo "  \"internalIngressIp\": \"$IP1.$IP2.$Y_PLUS_THREE.105\","
echo "  \"externalIngressIp\": \"1.2.3.4\","
echo "  \"dnsPrefix\": \"$dnsPrefix\","
echo "  \"deployDomain\": \"$deployDomain\","
echo "  \"dockerRegistry\": \"$dockerRegistry\","
echo "  \"k8sServiceHost\": \""$resourceGroup-dns-XXXXXXX"\","
echo "  \"aksAadClientId\": \"$aksAadClientId\","
echo "  \"aksAadServerId\": \"$aksAadServerId\","
echo "  \"aksAadServerSecret\": \"$aksAadServerSecret\","
echo "  \"aksAadTenantId\": \"$aksAadTenantId\","
echo "  \"akcPrincipal\": \"$akcPrincipal\","
echo "  \"akcPrincipalPassword\": \"$akcPrincipalPassword\","
echo "  \"branchName\": \"$branchName\","
echo "  \"jenkinsServicePrincipal\": \"$jenkinsServicePrincipal\","
echo "  \"jenkinsGlobalServicePrincipal\": \"$jenkinsGlobalServicePrincipal\","
echo "  \"jenkinsBuildType\": \"$jenkinsBuildType\","
echo "  \"deploymentDir\": \"$deploymentDir\","
echo "  \"projectsDir\": \"$projectsDir\","
echo "  \"secretsDir\": \"$secretsDir\","
echo "  \"modulesDir\": \"$modulesDir\","
echo "  \"radconnectImage\": \"$radconnectImage\","
echo "  \"imageViewerImage\": \"$imageViewerImage\","
echo "  \"seedImage\": \"$seedImage\","
echo "  \"backupServiceImage\": \"$backupServiceImage\","
echo "  \"isSharedService\": \"$isSharedService\","
echo "  \"frameAncestors\": \"$frameAncestors\","
echo "  \"mongos\": ["
echo "    {"
echo "      \"name\": \"mongo1\","
echo "      \"ipAddress\": \"$mongo1\""
echo "    },"
echo "    {"
echo "      \"name\": \"mongo2\","
echo "      \"ipAddress\": \"$mongo2\""
echo "    },"
echo "    {"
echo "      \"name\": \"mongo3\","
echo "      \"ipAddress\": \"$mongo3\""
echo "    }"
echo "  ]"
echo "}"

exit 0