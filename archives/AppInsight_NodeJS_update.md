#### To update a Nodejs Application Insight with a pre-existing code:

To update Azure Container App to use a pre-existing Application Insight instance, you would need to instrument your application with the Application Insights SDK and set the connection string or instrumentation key appropriately. Here's how you can do it:

1. Import the 'applicationinsights' package into your application code if it isn't already. If your code is in JavaScript(Node.js), you can use the following command to install it:
   ```
   npm install applicationinsights --save
   ```
   
2. Add the following lines of code at the beginning of your main application code file (before any other `require` statements):

   ```javascript
    const appInsights = require("applicationinsights");
    appInsights.setup("<KEY>");
    appInsights.start();
   ```
   Replace `"<KEY>"` with your actual Application Insights Instrumentation key.

3. To update the Azure Container app configuration to tie it directly with the Application Insights instance, you need to set the APPINSIGHTS_INSTRUMENTATIONKEY environment variable to your Insights Instrumentation Key in the configuration settings of your Container App. Here's how you can achieve this using Azure CLI:

   ```shell
    az containerapp update --name myapp --resource-group myrg --secrets APPINSIGHTS_INSTRUMENTATIONKEY='7a2fe918-54f4-4536-8fd6-e68eb7eac73c'
   ```
   
4. If you wish to set the configuration with Azure portal, navigate to your container app resource, select Settings > Environment variables > Add.

References:
- [Application Insights for Node.js - Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/app/nodejs)
- [Set up Azure Monitor for containers - Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-agent-install)
- [Azure CLI for Azure Container Apps](https://docs.microsoft.com/en-us/cli/azure/preview/containerapp?view=azure-cli-latest#az_containerapp_create-preview)

Please note that directly logging from Container App to Application Insights is made better through the SDK, not via environmental variables or direct logging. Also, always make sure your keys, connection strings etc., are stored securely and not exposed in your application code.

