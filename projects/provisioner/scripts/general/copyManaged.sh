#Provide the subscription Id of the subscription where managed disk exists
sourceSubscriptionId=510dd537-5356-41c7-b31d-65d9a93016e1

#Provide the name of your resource group where managed disk exists
sourceResourceGroupName=PackerImages

#Provide the name of the managed disk
managedDiskName=NucleusSingleBoxBaseImage-5.0.2

#Set the context to the subscription Id where managed disk exists
az account set --subscription $sourceSubscriptionId

#Get the managed disk Id 
managedDiskId=$(az disk show --name $managedDiskName --resource-group $sourceResourceGroupName --query [id] -o tsv)

#If managedDiskId is blank then it means that managed disk does not exist.
echo 'source managed disk Id is: ' $managedDiskId

#Provide the subscription Id of the subscription where managed disk will be copied to
targetSubscriptionId=02b0c8a5-ded5-40d5-96a2-35a9665a56d0

#Name of the resource group where managed disk will be copied to
targetResourceGroupName=PackerImages-central

#Set the context to the subscription Id where managed disk will be copied to
az account set --subscription $targetSubscriptionId

#Copy managed disk to different subscription using managed disk Id
az disk create --resource-group $targetResourceGroupName --name $managedDiskName --source $managedDiskId

