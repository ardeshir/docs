Okay, this is a common migration path! We'll adapt the `QueueMonitorApp` to work with an Azure Service Bus Queue instead of an Azure Storage Account Queue. The core logic of checking depth, alerting, and storing results will remain, but we'll swap out the Azure SDK components for Service Bus.

**Key Changes:**

1.  **NuGet Package:** Replace `Azure.Storage.Queues` with `Azure.Messaging.ServiceBus`.
2.  **Configuration:**
    *   We'll need a connection string for your Service Bus namespace (`servicebus-fsdi-dev`).
    *   The queue name is `solver-request`.
    *   The `topicName: solver-response` is not directly used for monitoring the *queue depth* of `solver-request`. It might be relevant for other parts of your application, but for this specific function's task, we focus on the queue.
3.  **SDK Clients:**
    *   Instead of `QueueServiceClient`, we'll primarily use `ServiceBusAdministrationClient` to get queue runtime properties like the active message count.
    *   The `ServiceBusClient` can also be used if you need to send/receive messages, but for just getting metadata, `ServiceBusAdministrationClient` is more direct.
4.  **Getting Message Count:** We'll use `GetQueueRuntimePropertiesAsync(queueName).ActiveMessageCount`.

---

**Step-by-Step Guide with Refactored Code:**

**1. Update Project Dependencies (`.csproj`):**

Modify your `QueueMonitorApp.csproj` file:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <AzureFunctionsVersion>v4</AzureFunctionsVersion>
    <OutputType>Exe</OutputType>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <LangVersion>12.0</LangVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Azure.Identity" Version="1.11.0" />
    <PackageReference Include="Azure.Messaging.ServiceBus" Version="7.17.5" /> <!-- Changed -->
    <PackageReference Include="Azure.Storage.Blobs" Version="12.19.1" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.21.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.1.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Timer" Version="4.3.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.0" />
    <PackageReference Include="Microsoft.Extensions.Azure" Version="1.7.3" />
    <PackageReference Include="Microsoft.Extensions.Configuration.EnvironmentVariables" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.DependencyInjection" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Http" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Logging.Console" Version="8.0.0" />
  </ItemGroup>
  <ItemGroup>
    <None Update="host.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
    <None Update="local.settings.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
      <CopyToPublishDirectory>Never</CopyToPublishDirectory>
    </None>
  </ItemGroup>
  <ItemGroup>
    <Using Include="System.Threading.ExecutionContext" Static="true" />
  </ItemGroup>
</Project>
```
*Make sure to run `dotnet restore` after updating the .csproj file.*

---

**2. Update `local.settings.json`:**

Add your Service Bus connection string and update the queue name.

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "YOUR_PRIMARY_STORAGE_ACCOUNT_CONNECTION_STRING_FOR_BLOBS_AND_FUNCTION_HOST",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "APP_SERVICEBUS_CONNECTION_STRING": "Endpoint=sb://servicebus-fsdi-dev.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=YOUR_SERVICE_BUS_NAMESPACE_KEY", // Replace with your actual SB connection string
    "APP_SERVICEBUS_QUEUE_NAME": "solver-request",
    "APP_ALERT_THRESHOLD": "50",
    "APP_ALERT_URL": "https://book.univrs.io/MarkD",
    "APP_RESULTS_CONTAINER_NAME": "data-in"
  }
}
```
*   **`AzureWebJobsStorage`**: This is still needed for the Functions host and for your blob storage results container if they share the same storage account.
*   **`APP_SERVICEBUS_CONNECTION_STRING`**: Get this from your Service Bus Namespace in the Azure portal (Shared access policies -> RootManageSharedAccessKey or a custom one with Manage/Listen rights). **It's best practice to create a dedicated shared access policy with only the necessary permissions (e.g., Listen for the queue, or Manage if the function might create the queue).**
*   **`APP_SERVICEBUS_QUEUE_NAME`**: Set to `solver-request`.

---

**3. Update Configuration Options Class (`FunctionSettings.cs`):**

```csharp
namespace QueueMonitorApp;

public class FunctionSettings
{
    // For Service Bus
    public required string ServiceBusConnectionString { get; set; }
    public required string ServiceBusQueueName { get; set; }

    // For Alerting
    public required int AlertThreshold { get; set; }
    public required string AlertUrl { get; set; }

    // For Blob Results
    public required string ResultsContainerName { get; set; }
    public string? StorageConnectionStringForBlobs { get; set; } // From AzureWebJobsStorage
}
```

---

**4. Update `Program.cs` for DI and Configuration:**

```csharp
using Azure.Identity;
using Azure.Messaging.ServiceBus.Administration; // For ServiceBusAdministrationClient
using Microsoft.Extensions.Azure;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using QueueMonitorApp;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureAppConfiguration((context, config) =>
    {
        config.AddEnvironmentVariables();
    })
    .ConfigureServices((context, services) =>
    {
        services.AddOptions<FunctionSettings>()
            .Configure<IConfiguration>((settings, configuration) =>
            {
                settings.ServiceBusConnectionString = configuration["APP_SERVICEBUS_CONNECTION_STRING"]
                    ?? throw new ArgumentNullException(nameof(settings.ServiceBusConnectionString), "Service Bus Connection String not configured.");
                settings.ServiceBusQueueName = configuration["APP_SERVICEBUS_QUEUE_NAME"]
                    ?? throw new ArgumentNullException(nameof(settings.ServiceBusQueueName), "Service Bus Queue Name not configured.");
                settings.AlertThreshold = int.Parse(configuration["APP_ALERT_THRESHOLD"] ?? "50");
                settings.AlertUrl = configuration["APP_ALERT_URL"]
                    ?? throw new ArgumentNullException(nameof(settings.AlertUrl), "Alert URL not configured.");
                settings.ResultsContainerName = configuration["APP_RESULTS_CONTAINER_NAME"] ?? "queue-results";
                settings.StorageConnectionStringForBlobs = configuration["AzureWebJobsStorage"];
            });

        services.AddHttpClient();

        // Register Azure SDK clients
        services.AddAzureClients(clientBuilder =>
        {
            // Blob Service Client (for storing results)
            // Assumes AzureWebJobsStorage is the connection string for the blob storage
            var blobStorageConnectionString = context.Configuration["AzureWebJobsStorage"];
            if (string.IsNullOrEmpty(blobStorageConnectionString))
            {
                throw new InvalidOperationException(
                    "AzureWebJobsStorage (for blob client) not found. Ensure it is configured.");
            }
            clientBuilder.AddBlobServiceClient(blobStorageConnectionString);


            // For Service Bus Administration Client:
            // We will register ServiceBusAdministrationClient directly as it's what we need.
            // It can be constructed from the connection string.
            // If using DefaultAzureCredential for Service Bus, the setup would be different here.
        });

        // More direct way to register ServiceBusAdministrationClient if primarily using connection strings
        services.AddSingleton(provider =>
        {
            var functionSettings = provider.GetRequiredService<IOptions<FunctionSettings>>().Value;
            // If you plan to use DefaultAzureCredential for Service Bus:
            // return new ServiceBusAdministrationClient(new Uri($"sb://{your-namespace}.servicebus.windows.net/"), new DefaultAzureCredential());
            // For connection string:
            return new ServiceBusAdministrationClient(functionSettings.ServiceBusConnectionString);
        });


        services.AddLogging(loggingBuilder =>
        {
            loggingBuilder.AddConsole();
        });
    })
    .Build();

host.Run();
```
**Key changes in `Program.cs`:**
*   Updated `FunctionSettings` binding.
*   The `AddAzureClients` block for `BlobServiceClient` remains similar (assuming `AzureWebJobsStorage` is still used for that).
*   We're now directly registering `ServiceBusAdministrationClient` as a singleton. This client is specifically for management operations like getting queue properties. If you were using `DefaultAzureCredential` for Service Bus, you'd integrate it here, likely using the `clientBuilder.AddClient<ServiceBusAdministrationClient, ...>` approach or passing the namespace URI and credential to the constructor. For connection strings, direct instantiation is straightforward.

---

**5. Refactor the Function (`QueueMonitorFunction.cs`):**

```csharp
using Azure.Messaging.ServiceBus.Administration; // For ServiceBusAdministrationClient and QueueRuntimeProperties
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace QueueMonitorApp;

// Using C# 12 Primary Constructor
public class QueueMonitorFunction(
    ILogger<QueueMonitorFunction> logger,
    IHttpClientFactory httpClientFactory,
    ServiceBusAdministrationClient serviceBusAdminClient, // Changed
    BlobServiceClient blobServiceClient,
    IOptions<FunctionSettings> settings)
{
    private readonly FunctionSettings _settings = settings.Value;

    [Function("QueueMonitorFunction")]
    public async Task RunAsync([TimerTrigger("0 */1 * * * *")] TimerInfo myTimer)
    {
        _logger.LogInformation("C# Timer trigger function for Service Bus Queue executed at: {Timestamp}", DateTime.Now);
        _logger.LogInformation("Next timer schedule at: {NextSchedule}", myTimer.ScheduleStatus?.Next);

        var resultLog = new ResultLogEntry
        {
            Timestamp = DateTime.UtcNow,
            QueueName = _settings.ServiceBusQueueName, // Updated property name
            AlertThreshold = _settings.AlertThreshold
        };

        try
        {
            _logger.LogInformation("Checking Service Bus Queue: {QueueName}", _settings.ServiceBusQueueName);

            // Get queue runtime properties using ServiceBusAdministrationClient
            QueueRuntimeProperties queueProperties =
                await _serviceBusAdminClient.GetQueueRuntimePropertiesAsync(_settings.ServiceBusQueueName);

            long messageCount = queueProperties.ActiveMessageCount; // Service Bus uses ActiveMessageCount
            resultLog.CurrentQueueDepth = (int)messageCount; // Cast to int for consistency if your model expects it

            _logger.LogInformation("Service Bus Queue '{QueueName}' current active message count: {MessageCount}",
                _settings.ServiceBusQueueName, messageCount);

            if (messageCount > _settings.AlertThreshold)
            {
                _logger.LogWarning("Service Bus Queue '{QueueName}' depth ({MessageCount}) exceeds threshold ({Threshold}). Sending alert.",
                    _settings.ServiceBusQueueName, messageCount, _settings.AlertThreshold);

                resultLog.AlertTriggered = true;
                var alertPayload = new { Body = $"Alert: Service Bus Queue '{_settings.ServiceBusQueueName}' depth is {messageCount}, exceeding threshold of {_settings.AlertThreshold}." };
                string jsonPayload = JsonSerializer.Serialize(alertPayload);
                var content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");

                HttpClient httpClient = _httpClientFactory.CreateClient();
                HttpResponseMessage response = await httpClient.PostAsync(_settings.AlertUrl, content);

                resultLog.AlertUrl = _settings.AlertUrl;
                resultLog.AlertStatusCode = (int)response.StatusCode;

                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Alert sent successfully to {AlertUrl}. Status: {StatusCode}", _settings.AlertUrl, response.StatusCode);
                    resultLog.AlertSuccess = true;
                }
                else
                {
                    string errorResponse = await response.Content.ReadAsStringAsync();
                    _logger.LogError("Failed to send alert to {AlertUrl}. Status: {StatusCode}. Response: {ErrorResponse}",
                        _settings.AlertUrl, response.StatusCode, errorResponse);
                    resultLog.AlertSuccess = false;
                    resultLog.AlertErrorMessage = $"Status: {response.StatusCode}, Response: {errorResponse}";
                }
            }
            else
            {
                _logger.LogInformation("Service Bus Queue '{QueueName}' depth ({MessageCount}) is within threshold ({Threshold}). No alert sent.",
                    _settings.ServiceBusQueueName, messageCount, _settings.AlertThreshold);
                resultLog.AlertTriggered = false;
            }
        }
        catch (Azure.RequestFailedException rfEx) when (rfEx.Status == 404)
        {
            _logger.LogError(rfEx, "Service Bus Queue '{QueueName}' not found. Please ensure it exists in namespace '{Namespace}'. Error: {ErrorMessage}",
                _settings.ServiceBusQueueName, _serviceBusAdminClient.FullyQualifiedNamespace, rfEx.Message);
            resultLog.Error = $"Queue '{_settings.ServiceBusQueueName}' not found. {rfEx.Message}";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing Service Bus Queue '{QueueName}': {ErrorMessage}", _settings.ServiceBusQueueName, ex.Message);
            resultLog.Error = ex.Message;
        }
        finally
        {
            await StoreResultAsync(resultLog);
        }

        _logger.LogInformation("Service Bus Queue monitoring finished for '{QueueName}'.", _settings.ServiceBusQueueName);
    }

    private async Task StoreResultAsync(ResultLogEntry resultLog)
    {
        // This method remains the same as it deals with Blob Storage
        try
        {
            BlobContainerClient containerClient = _blobServiceClient.GetBlobContainerClient(_settings.ResultsContainerName);
            await containerClient.CreateIfNotExistsAsync(PublicAccessType.None);

            string blobName = $"{resultLog.Timestamp:yyyyMMddHHmmssfff}_{_settings.ServiceBusQueueName}_status.json"; // Using SB queue name in blob
            string jsonResult = JsonSerializer.Serialize(resultLog, new JsonSerializerOptions { WriteIndented = true });

            BlobClient blobClient = containerClient.GetBlobClient(blobName);
            using var stream = new MemoryStream(Encoding.UTF8.GetBytes(jsonResult));
            await blobClient.UploadAsync(stream, overwrite: true);

            _logger.LogInformation("Successfully stored result to blob: {ContainerName}/{BlobName}", _settings.ResultsContainerName, blobName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to store result for Service Bus queue '{QueueName}' to blob storage: {ErrorMessage}", _settings.ServiceBusQueueName, ex.Message);
        }
    }
}

// Update ResultLogEntry if needed (QueueName property is already generic)
public class ResultLogEntry
{
    public DateTime Timestamp { get; set; }
    public required string QueueName { get; set; } // This is fine, will now hold the SB Queue Name
    public int AlertThreshold { get; set; }
    public int CurrentQueueDepth { get; set; } // Make sure this can accommodate 'long' or cast appropriately
    public bool AlertTriggered { get; set; }
    public string? AlertUrl { get; set; }
    public bool? AlertSuccess { get; set; }
    public int? AlertStatusCode { get; set; }
    public string? AlertErrorMessage { get; set; }
    public string? Error { get; set; }
}
```
**Key changes in `QueueMonitorFunction.cs`:**
*   Injected `ServiceBusAdministrationClient`.
*   Used `_serviceBusAdminClient.GetQueueRuntimePropertiesAsync(_settings.ServiceBusQueueName)` to get queue details.
*   Accessed `queueProperties.ActiveMessageCount` for the depth.
*   Updated log messages to refer to "Service Bus Queue".
*   Added a specific catch for `Azure.RequestFailedException` with status 404 to provide a better error message if the queue doesn't exist.
*   The `ResultLogEntry.QueueName` will now store the Service Bus queue name.
*   The `StoreResultAsync` method is largely unchanged as it pertains to Blob storage, but the blob name now reflects the Service Bus queue name for clarity.

---

**6. Build, Test, and Deploy:**

*   **Build:** `dotnet build`
*   **Test Locally:** `func start`
    *   Ensure your `local.settings.json` has the correct `APP_SERVICEBUS_CONNECTION_STRING` and `APP_SERVICEBUS_QUEUE_NAME`.
    *   The Service Bus queue `solver-request` must exist in the `servicebus-fsdi-dev` namespace.
    *   The identity used (via connection string or Managed Identity if you adapt for it) needs at least "Azure Service Bus Data Receiver" role on the queue to read properties, or "Azure Service Bus Data Owner" / "Contributor" for broader permissions if the `ServiceBusAdministrationClient` needs them (typically, "Reader" on the namespace and "Receiver" on the queue is enough for runtime properties). For `ServiceBusAdministrationClient`, you often need "Manage" permission on the specific queue or "Owner" on the namespace. The `RootManageSharedAccessKey` connection string will definitely work.
*   **Deploy to Azure:**
    *   Update your Azure Function App's Application Settings with:
        *   `APP_SERVICEBUS_CONNECTION_STRING`
        *   `APP_SERVICEBUS_QUEUE_NAME`
        *   (And other settings like `APP_ALERT_THRESHOLD`, `APP_ALERT_URL`, `APP_RESULTS_CONTAINER_NAME`, `AzureWebJobsStorage` if not already set).
    *   `func azure functionapp publish YourFunctionAppName`

This migration provides the same functionality but tailored for Azure Service Bus Queues. Remember to handle permissions carefully, especially if moving towards Managed Identity for Service Bus access in Azure.
