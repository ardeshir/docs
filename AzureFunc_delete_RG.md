#####Q: Azure Function that uses the armClient to iterate over all the subscription looking for Resource Groups and deleting the ones with zero resources in them! 

#####A: 

```csharp
using System;  
using System.Threading.Tasks;  
using Microsoft.Azure.Services.AppAuthentication;  
using Microsoft.Azure.Management.Fluent;  
using Microsoft.Azure.Management.ResourceManager.Fluent;  
using Microsoft.Azure.Management.ResourceManager.Fluent.Authentication;  
using Microsoft.Azure.WebJobs;  
using Microsoft.Extensions.Logging;  
  
public static class CleanEmptyResourceGroups  
{  
    [FunctionName("CleanEmptyResourceGroups")]  
    public static async Task Run([TimerTrigger("0 0 * * * *")]TimerInfo myTimer, ILogger log)  
    {  
        var azureServiceTokenProvider = new AzureServiceTokenProvider();  
        var accessToken = await azureServiceTokenProvider.GetAccessTokenAsync("https://management.azure.com/");  
        var credentials = new AzureCredentials(new MSILoginInformation(MSIResourceType.AppService), AzureEnvironment.AzureGlobalCloud);  
        var azure = Azure.Configure().WithLogLevel(HttpLoggingDelegatingHandler.Level.Basic).Authenticate(credentials).WithDefaultSubscription();  
  
        var subscriptions = await azure.Subscriptions.ListAsync();  
        foreach (var subscription in subscriptions)  
        {  
            var resourceGroups = await azure.WithSubscription(subscription.SubscriptionId).ResourceGroups.ListAsync();  
            foreach (var resourceGroup in resourceGroups)  
            {  
                var resources = await azure.WithSubscription(subscription.SubscriptionId).ResourceManager.Resources.ListByResourceGroupAsync(resourceGroup.Name);  
                if (!resources.GetEnumerator().MoveNext())  
                {  
                    log.LogInformation($"Deleting resource group {resourceGroup.Name}");  
                    await azure.WithSubscription(subscription.SubscriptionId).ResourceGroups.DeleteByNameAsync(resourceGroup.Name);  
                }  
            }  
        }  
    }  
}
```
#####This function uses a timer trigger to run at a specified schedule. The Managed Identity of the Function App is used to authenticate with Azure. The function then lists all subscriptions, resource groups, and resources, and deletes any resource groups that contain no resources.

#####Note:

Make sure your Azure Function App has a system-assigned Managed Identity and it has enough permissions (contributor role on the subscription should be fine) to list and delete the resource groups.
Install Microsoft.Azure.Management.Fluent and Microsoft.Azure.Services.AppAuthentication NuGet packages.
Be very cautious with this function because it deletes resource groups. Test it thoroughly to ensure it behaves as expected.

- Sources:
- https://docs.microsoft.com/en-us/dotnet/api/overview/azure/identity-readme
- https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview
- https://github.com/Azure-Samples/azure-samples-net-management  
