##### Q: How do I use the Azure CLI to find the name of Service Principle from the Object ID: 3f5e05c6-ae66-4965-98df-3d19eb6fbb17 ?  I need to give Azure DevOps Service Principle permissions to a resource Group, but I only have the Object ID, and need the name? 

A: To find the name of an App Client ID and Service Principal from the Object ID using Azure CLI, you can use the command az ad sp show --id. Here is an example:

#### How to grab name from ClientApp ID
  
```shell
az login --tenant <GUID_TENANT>
az ad app list --query "[?appId=='292d418e-d27e-4eed-bd5f-94ea27b4a7f3'].{Name:displayName}" --output table
Name
-------------
APIM-TOKEN-SP
```

### How to grab Service Principle Name from ID

```shell
az ad sp show --id 3f5e05c6-ae66-4965-98df-3d19eb6fbb17
```
 
This command will return a JSON object that contains the details of the Service Principal. You can find the name of the Service Principal under the displayName property.

Remember, you need to be logged in to the Azure CLI and have the necessary permissions to view Service Principal details.

Also, keep in mind that Azure DevOps uses Service Connections to interact with Azure. These are not always directly related to Service Principals. If you are trying to give Azure DevOps access to a resource group, you might want to look into creating a Service Connection in Azure DevOps and assigning it the necessary permissions on Azure.

***Check out the following documentation for more details:***

- Azure CLI: https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest#az_ad_sp_show

- Service Connections in Azure DevOps: https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml

- Assign Azure role for access to resource group: https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal


