#!/usr/bin/env bash

#servicePrincipalName=Nucleus-shared-services-peerings
#servicePrincipalId=19714e41-ca17-4dad-9e7e-1f69e2eef7af
#servicePrincipalPassword=XXXXXXXX

#sharedServicesName=shared-services
#sharedServicesTernantId=418b0446-911f-42b4-8c8c-c4e27a1be63c
#sharedServicesSubscriptionId=c5737d32-09d4-4cae-bf13-ad5dd93cf0c4

#nucleusName=chcotest
#nucleusTenantId=af8d3786-f13d-43d5-b752-d893b9462e87
#nucleusSubscriptionId=14b05e8c-2090-4260-8d48-8d79a3715a48

echo "You must edit the variables at the top of this file prior to running it"
exit

# Get the access tokens to be able to reference the remote vnet when logged into the other tenant

echo "Logging into the Shared Services tenant"

az logout
az account clear
az login --service-principal -u "$servicePrincipalId" -p "$servicePrincipalPassword" --tenant "$sharedServicesTernantId"
if [ $? -ne 0 ]; then
        echo "An error occurred logging into tenant ID $sharedServicesTernantId with the service principal ID $servicePrincipalId"
        exit 1
fi

az account get-access-token
if [ $? -ne 0 ]; then
        echo "An error occurred getting the access token for tenant ID $sharedServicesTernantId with the service principal ID $servicePrincipalId"
        exit 1
fi

echo "Logging into the Nucleus tenant"

az login --service-principal -u "$servicePrincipalId" -p "$servicePrincipalPassword" --tenant "$nucleusTenantId"
if [ $? -ne 0 ]; then
        echo "An error occurred logging into tenant ID $nucleusTenantId with the service principal ID $servicePrincipalId"
        exit 1
fi

az account get-access-token
if [ $? -ne 0 ]; then
        echo "An error occurred getting the access token for tenant ID $nucleusTenantId with the service principal ID $servicePrincipalId"
        exit 1
fi

## Setting up vnet peering:

echo "Logging into the Shared Services tenant"

az login --service-principal -u "$servicePrincipalId" -p "$servicePrincipalPassword" --tenant "$sharedServicesTernantId"
if [ $? -ne 0 ]; then
        echo "An error occurred logging into tenant ID $sharedServicesTernantId with the service principal ID $servicePrincipalId"
        exit 1
fi

echo "Creating the Shared Services -> Nucleus vnet peering"

az network vnet peering create --name "to_$nucleusName" --resource-group "$sharedServicesName" --allow-vnet-access --allow-forwarded-traffic --vnet-name "$sharedServicesName-vnet" \
--remote-vnet "/subscriptions/$nucleusSubscriptionId/resourceGroups/$nucleusName/providers/Microsoft.Network/virtualNetworks/$nucleusName-network"
if [ $? -ne 0 ]; then
        echo "An error occurred creating the vnet peering from the Shared Services vnet to the Nucleus vnet"
        exit 1
fi

echo "Logging into the Nucleus tenant"

az login --service-principal -u "$servicePrincipalId" -p "$servicePrincipalPassword" --tenant "$nucleusTenantId"
if [ $? -ne 0 ]; then
        echo "An error occurred logging into tenant ID $nucleusTenantId with the service principal ID $servicePrincipalId"
        exit 1
fi

echo "Creating the Nucleus -> Shared Services vnet peering"

az network vnet peering create --name "to_$sharedServicesName" --resource-group "$nucleusName" --allow-vnet-access --allow-forwarded-traffic --vnet-name "$nucleusName-network" \
--remote-vnet "/subscriptions/$sharedServicesSubscriptionId/resourceGroups/$sharedServicesName/providers/Microsoft.Network/virtualNetworks/$sharedServicesName-vnet"
if [ $? -ne 0 ]; then
        echo "An error occurred creating the vnet peering from the Nucleus vnet to the Shared Services vnet"
        exit 1
fi

az logout
az account clear

echo "The vnet peerings have been created. Please verify their existance and configuration is correct via the Azure portal."
echo "You have been logged out of Azure."

