#### Bicep IaC for an Azure Container App to use a pre-existing Application Insight instance, such that all the logging for Azure Container app is sent to an already created with the following id information:
Instrumentation Key= 7a2fe918-54f4-4536-8fd6-e68eb7eac73c
Connection String= "InstrumentationKey=7a2fe918-54f4-4536-8fd6-e68eb7eac73c;IngestionEndpoint=https://eastus-5.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/"
Workspace= la-fsdi-shared
 

#### A: First, you need to update the Bicep file for your Azure Container App to reference the pre-existing Application Insights instance. The updated Bicep code can look like this:

```bicep
var instrumentationKey = '7a2fe918-54f4-4536-8fd6-e68eb7eac73c'
var connectionString = 'InstrumentationKey=7a2fe918-54f4-4536-8fd6-e68eb7eac73c;IngestionEndpoint=https://eastus-5.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/'

var workspace = 'la-fsdi-shared'

resource app 'Microsoft.Web/sites@2021-01-15' = {
  name: 'yourContainerAppName'
  // Rest of your properties
  properties: {
    // Rest of your properties
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: instrumentationKey
        },
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: connectionString
        }]
      }
  }
}
```

After this step, compile your Bicep file into an ARM template using the Azure CLI command:

```shell
az bicep build --file {your filepath to the bicep file}
```

Then deploy the generated `.json` file to Azure:

```shell
az deployment group create --resource-group {Your resource group} --template-file {Generated .json file path}
```

Once the deployment is completed, your Azure Container App should start sending logs to the referenced Application Insights instance.

Please replace the placeholder such as {yourContainerAppName}, {Your resource group}, and {your filepath to the bicep file} with your actual information.

Resources: 
- [Azure Resource Manager Bicep documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview)
- [Use Azure Application Insights with Azure Web Apps](https://docs.microsoft.com/en-us/azure/azure-monitor/app/azure-web-apps#:~:text=Instrumentation%20key&text=The%20key%20is%20linked%20to,with%20a%20connection%20string%20instead.)
- [Deploy resources with Bicep and ARM template](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deploy-cli)

