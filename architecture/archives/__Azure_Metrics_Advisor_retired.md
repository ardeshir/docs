# Azure.Identity and Azure SDK API to review Azure monitoring alert logs

.NET 6 has introduced top-level statements, making it convenient to register dependencies in the Program.cs. Here is a simplified example that sets up a .NET 6 console application using Azure.Identity and Azure SDK API to review Azure monitor alert logs and register them in the built-in dependency injection.

Please make sure you have the following NuGet packages installed:

- Azure.Identity
- Azure.Management.Monitor

In this example, I'm creating a `MonitorLogsService`, which retrieves alert logs from Azure.

```csharp
using Azure.Identity;
using Azure.Management.Monitor;
using Azure.Management.Monitor.Models;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Threading.Tasks;

public class MonitorLogsService
{
    private readonly MonitorManagementClient _monitorManagementClient;
    public MonitorLogsService(MonitorManagementClient monitorManagementClient)
    {
        _monitorManagementClient = monitorManagementClient;
    }

    public async Task FetchActivityLogsAsync()
    {
        // Replace 'filter' and 'select' as per your requirement
        var activityLogs = await _monitorManagementClient.ActivityLogs.ListAsync(
                filter: "startswith(eventTimestamp, '2022-01-01') and resourceUri eq '/subscriptions/<subscription-id>'",
                select: "eventTimestamp,operationName");

        foreach (var log in activityLogs)
        {
            Console.WriteLine($"{log.EventTimestamp}: {log.OperationName?.Value}");
        }
    }
}
```

A `Program.cs` file:

```csharp
using Azure.Identity;
using Azure.Management.Monitor;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Threading.Tasks;

var serviceProvider = new ServiceCollection()
    .AddSingleton(s =>
    {
        var azureCredential = new DefaultAzureCredential();
        return new MonitorManagementClient(azureCredential);
    })
    .AddTransient<MonitorLogsService>()
    .BuildServiceProvider();

var monitorService = serviceProvider.GetRequiredService<MonitorLogsService>();
await monitorService.FetchActivityLogsAsync();
```

In this example, `ActivityLogs.ListAsync()` is being used to fetch the activity logs, and you need to replace `'filter'` and `'select'` parameters with your actual requirement. The `MonitorLogsService` is registered using Dependency Injection in the `Program.cs`. Then it's used to fetch and print out the logs.

Please remember to replace subscription details `<subscription-id>` with your actual subscription ID.

References:

- Azure.Identity - https://www.nuget.org/packages/Azure.Identity/
- Azure.Management.Monitor - https://www.nuget.org/packages/Azure.Management.Monitor/

### create a .NET 6 Console application that uses Azure.Identity and Azure SDK API for Azure monitor alert logs and register them in the built-in dependency injection, follow the steps below.

1. First, create a new console application targeting .NET 6 using the dotnet CLI.

```bash
dotnet new console -n AzureMonitorApp
cd AzureMonitorApp
```

2. Then, install the required Azure SDKs and Azure.Identity packages using the dotnet CLI.

```bash
dotnet add package Azure.Identity
dotnet add package Azure.AI.MetricsAdvisor --version 1.0.0
```

3. In the Program.cs, import the necessary namespaces.

```csharp
using Azure;
using Azure.AI.MetricsAdvisor;
using Azure.AI.MetricsAdvisor.Models;
using Azure.Identity;
```

4. If you want to use dependency injection, you have to include the `Microsoft.Extensions.DependencyInjection` package.

```bash
dotnet add package Microsoft.Extensions.DependencyInjection
```

Afterwards, set up the dependency injection container in your `Main` method:

```csharp
static void Main(string[] args)
{
    var services = new ServiceCollection();
    services.AddSingleton(new DefaultAzureCredential());
    services.AddSingleton(new Uri("<Your Metrics Advisor endpoint>"));
    services.AddTransient(serviceProvider =>
    {
        var credential = serviceProvider.GetRequiredService<DefaultAzureCredential>();
        var endpoint = serviceProvider.GetRequiredService<Uri>();
        return new MetricsAdvisorClient(endpoint, credential);
    });

    var serviceProvider = services.BuildServiceProvider();
    var metricsAdvisorClient = serviceProvider.GetRequiredService<MetricsAdvisorClient>();

    // Your code follows here...
}
```

5. Use the `MetricsAdvisorClient` instance to interact with Azure Monitor Alert Logs.

Please replace `<Your Metrics Advisor endpoint>` with the actual endpoint of your Metrics Advisor resource.

Please note that Azure Monitor Alert logs can be interacted with Azure Log Analytics Query using Azure SDK for .NET and for this, you may need to include `Azure.AI.OperationalInsights` package and use `LogsQueryClient`. Azure.AI.MetricsAdvisor is for interacting with Metrics Advisor related services.

For more information about Azure SDK and Azure.Identity you can visit these links

- Azure SDKs: https://azure.github.io/azure-sdk/releases/latest/dotnet.html
- Azure.Identity: https://github.com/Azure/azure-sdk-for-net/tree/main/sdk/identity/Azure.Identity

You may need to configure Azure security permissions for your application to properly interact with Azure Monitor Alert Logs and/or Metrics Advisor.

Remember to always test your components separately and secure your application key when running on production.
Microsoft Azure provides a few resources on how to use the `Azure.AI.MetricsAdvisor` to query alerts. Below are a couple of useful links for your reference:

1. Microsoft Documentation page, provides a detailed overview about Azure AI Metrics Advisor client library for .NET: https://docs.microsoft.com/en-us/azure/cognitive-services/metrics-advisor/how-tos/how-to-use-client-libraries

2. Azure SDK Github Repository: https://github.com/Azure/azure-sdk-for-net/tree/main/sdk/metricsadvisor/Azure.AI.MetricsAdvisor

   Here you can find various examples demonstrating the usage of the Azure.AI.MetricsAdvisor, as well as the Alerts' functionalities.

3. The official Microsoft Documentation explains how to manage alerts with Azure Metrics Advisor: https://docs.microsoft.com/en-us/azure/cognitive-services/metrics-advisor/how-tos/manage-alerts-hooks

Also, I need to mention that the `serviceProvider.GetRequiredService<MetricsAdvisorClient>()` is a default method of the .NET dependency injection system. This method retrieves a service of the type specified (in this case, `MetricsAdvisorClient`). You need to add all the necessary services in the ConfigureServices method of the Startup class. You can find more information about this on Microsoft's Documentation page: https://docs.microsoft.com/en-us/dotnet/core/extensions/dependency-injection-usage


