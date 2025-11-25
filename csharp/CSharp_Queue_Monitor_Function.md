## C# Azure Function to .NET 9.0 (which implies using the Azure Functions .NET Isolated Worker model)

Queue Function that is more robust and modular, with functionality to store results in Azure Blob Storage.

**Key Improvements & Changes:**

1.  **.NET Isolated Worker Model:** This is the standard for .NET 5+ Azure Functions. It runs your function in a separate process from the Functions host, giving you more control over dependencies and .NET versions.
2.  **Latest Azure SDKs:** We'll use `Azure.Storage.Queues` and `Azure.Storage.Blobs` instead of the older `Microsoft.Azure.Storage.Queue`.
3.  **Dependency Injection (DI):** Heavily utilize DI for services like `QueueServiceClient`, `BlobContainerClient`, `HttpClientFactory`, and `ILogger`.
4.  **Configuration:** Use `IConfiguration` and strongly-typed options patterns for settings.
5.  **Robust Error Handling:** More comprehensive `try-catch` blocks.
6.  **Modularity:** Separate concerns into different services/classes where appropriate.
7.  **C# 12 Features:** We can leverage features like primary constructors if desired, though the major structural changes come from the isolated worker model and DI.
8.  **Result Storage:** Implement logic to write/append results to a specified blob container.
9.  **`async Task`:** Function signature will be `public async Task RunAsync(...)` instead of `public static async void Run(...)`.

---

**Step-by-Step Guide with Refactored Code:**

**Prerequisites:**

*   .NET 9 SDK (or the latest preview available when you implement this).
*   Azure Functions Core Tools (v4).
*   An Azure Subscription.
*   Azure Storage Account (with a queue and a blob container named `queue-results`).
*   Azure Function App (configured for .NET Isolated).

---

**1. Create or Update Project to .NET Isolated Worker for .NET 9.0:**

If starting new:
```bash
func init QueueMonitorApp --worker-runtime dotnet-isolated
cd QueueMonitorApp
func new --name QueueMonitorFunction --template "Timer trigger" --csharp
```

Modify the `.csproj` file (`QueueMonitorApp.csproj`):

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework> <!-- Or the specific .NET 9 version -->
    <AzureFunctionsVersion>v4</AzureFunctionsVersion>
    <OutputType>Exe</OutputType>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <!-- For C# 12 features if not implicitly enabled by TargetFramework -->
    <LangVersion>12.0</LangVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Azure.Identity" Version="1.11.0" />
    <PackageReference Include="Azure.Storage.Blobs" Version="12.19.1" />
    <PackageReference Include="Azure.Storage.Queues" Version="12.17.1" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.21.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.1.0" /> <!-- For HttpClientFactory -->
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Timer" Version="4.3.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.0" />
    <PackageReference Include="Microsoft.Extensions.Azure" Version="1.7.3" />
    <PackageReference Include="Microsoft.Extensions.Configuration.EnvironmentVariables" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.DependencyInjection" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Http" Version="8.0.0" />
    <PackageReference Include="Microsoft.Extensions.Logging.Console" Version="8.0.0" /> <!-- Optional for local console logging -->
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
*Note: Package versions might be newer; update as needed.*

---

**2. Configure `local.settings.json`:**

This file is used for local development. When deployed to Azure, these become Application Settings in the Function App.

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "YOUR_PRIMARY_STORAGE_CONNECTION_STRING", // Used by Functions host & for our queue/blob
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "APP_QUEUE_NAME": "your-queue-name", // Your specific queue name
    "APP_ALERT_THRESHOLD": "50",
    "APP_ALERT_URL": "https://book.univrs.io/MarkD", // Your alert endpoint
    "APP_RESULTS_CONTAINER_NAME": "queue-results"
  }
}
```
*For production, it's highly recommended to use Managed Identities for `AzureWebJobsStorage` if the Functions host supports it for all its needs, or at least for your custom queue/blob access.*

---

**3. Create Configuration Options Class:**

`FunctionSettings.cs`

```csharp
namespace QueueMonitorApp;

public class FunctionSettings
{
    public const string SectionName = "AppSettings"; // Optional, if you nest settings

    // Use 'required' keyword from C# 11+ for mandatory settings
    public required string QueueName { get; set; }
    public required int AlertThreshold { get; set; }
    public required string AlertUrl { get; set; }
    public required string ResultsContainerName { get; set; }
    public string? StorageConnectionString { get; set; } // For AzureWebJobsStorage if needed directly
}
```

---

**4. Modify `Program.cs` for DI and Configuration:**

`Program.cs`

```csharp
using Azure.Identity;
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
        // Add environment variables (local.settings.json maps to this locally)
        config.AddEnvironmentVariables();

        // You can add other configuration sources here, like Azure App Configuration
    })
    .ConfigureServices((context, services) =>
    {
        // Bind FunctionSettings from configuration
        // For values directly under "Values" in local.settings.json or App Settings
        services.AddOptions<FunctionSettings>()
            .Configure<IConfiguration>((settings, configuration) =>
            {
                settings.QueueName = configuration["APP_QUEUE_NAME"] ?? throw new ArgumentNullException(nameof(settings.QueueName));
                settings.AlertThreshold = int.Parse(configuration["APP_ALERT_THRESHOLD"] ?? "50");
                settings.AlertUrl = configuration["APP_ALERT_URL"] ?? throw new ArgumentNullException(nameof(settings.AlertUrl));
                settings.ResultsContainerName = configuration["APP_RESULTS_CONTAINER_NAME"] ?? "queue-results";
                settings.StorageConnectionString = configuration["AzureWebJobsStorage"]; // Get the primary storage connection string
            });

        // Register HttpClientFactory
        services.AddHttpClient();

        // Register Azure SDK clients
        // This uses DefaultAzureCredential which is good for Managed Identity in Azure
        // and various local credentials during development.
        // For explicit connection string usage (e.g. if DefaultAzureCredential is not configured for local dev for AzureWebJobsStorage):
        string storageConnectionString = context.Configuration["AzureWebJobsStorage"]!;

        services.AddAzureClients(clientBuilder =>
        {
            // Prefer Managed Identity if configured, otherwise fall back to connection string for local dev
            if (!string.IsNullOrEmpty(storageConnectionString) && storageConnectionString.Contains("AccountKey"))
            {
                 clientBuilder.AddQueueServiceClient(storageConnectionString)
                    .WithName("DefaultQueueClient"); // Name for specific injection if needed
                 clientBuilder.AddBlobServiceClient(storageConnectionString)
                    .WithName("DefaultBlobClient"); // Name for specific injection if needed
            }
            else // Assume Managed Identity or other DefaultAzureCredential supported methods
            {
                clientBuilder.AddQueueServiceClient(new Uri($"https://{context.Configuration["AzureWebJobsStorage_AccountName"]}.queue.core.windows.net"))
                    .WithCredential(new DefaultAzureCredential());
                clientBuilder.AddBlobServiceClient(new Uri($"https://{context.Configuration["AzureWebJobsStorage_AccountName"]}.blob.core.windows.net"))
                    .WithCredential(new DefaultAzureCredential());
            }
            // Note: AzureWebJobsStorage_AccountName would be derived if using Managed Identity.
            // If AzureWebJobsStorage is a full conn string, you might need to parse out the account name,
            // or simplify and just use the conn string for both local and Azure for Queue/Blob clients if MSI is complex for this app.
            // For simplicity with AzureWebJobsStorage, often using the connection string directly is fine.
        });

        // Add custom services (optional, but good for modularity)
        // services.AddTransient<IQueueService, QueueService>();
        // services.AddTransient<IAlertService, AlertService>();
        // services.AddTransient<IResultStorageService, ResultStorageService>();

        services.AddLogging(loggingBuilder =>
        {
            loggingBuilder.AddConsole(); // View logs in console when running locally
        });
    })
    .Build();

host.Run();
```
*Note on `AzureWebJobsStorage` and `DefaultAzureCredential`: `AzureWebJobsStorage` is often a connection string. `DefaultAzureCredential` is great for services *other than* the one `AzureWebJobsStorage` points to, unless you specifically configure the Function App's identity to have access to that storage account and set `AzureWebJobsStorage` to just the account name (or use service URI). For simplicity in this example, I'm showing how to potentially use the connection string from `AzureWebJobsStorage` explicitly for the `QueueServiceClient` and `BlobServiceClient` for robustness across environments.*
*A common pattern is to have `AzureWebJobsStorage` as a connection string and then a separate setting like `DataStorageAccountUri` for services you'll access with Managed Identity.*

*Simpler `AddAzureClients` if always using `AzureWebJobsStorage` connection string:*
```csharp
        services.AddAzureClients(clientBuilder =>
        {
            var connectionString = context.Configuration["AzureWebJobsStorage"];
            if (string.IsNullOrEmpty(connectionString))
            {
                throw new InvalidOperationException(
                    "AzureWebJobsStorage not found. Ensure it is configured in local.settings.json or App Settings.");
            }
            clientBuilder.AddQueueServiceClient(connectionString).WithName("storageQueueClient");
            clientBuilder.AddBlobServiceClient(connectionString).WithName("storageBlobClient");
        });
```

---

**5. Refactor the Function (`QueueMonitorFunction.cs`):**

We'll inject dependencies into the constructor.

```csharp
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Azure.Storage.Queues;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace QueueMonitorApp;

// Using C# 12 Primary Constructor for conciseness
public class QueueMonitorFunction(
    ILogger<QueueMonitorFunction> logger,
    IHttpClientFactory httpClientFactory,
    QueueServiceClient queueServiceClient, // Injected by AddAzureClients
    BlobServiceClient blobServiceClient,   // Injected by AddAzureClients
    IOptions<FunctionSettings> settings)
{
    private readonly FunctionSettings _settings = settings.Value;

    [Function("QueueMonitorFunction")]
    public async Task RunAsync([TimerTrigger("0 */1 * * * *")] TimerInfo myTimer)
    {
        _logger.LogInformation($"C# Timer trigger function executed at: {DateTime.Now}");
        _logger.LogInformation($"Next timer schedule at: {myTimer.ScheduleStatus?.Next}");

        var resultLog = new ResultLogEntry
        {
            Timestamp = DateTime.UtcNow,
            QueueName = _settings.QueueName,
            AlertThreshold = _settings.AlertThreshold
        };

        try
        {
            QueueClient queueClient = _queueServiceClient.GetQueueClient(_settings.QueueName);
            await queueClient.CreateIfNotExistsAsync(); // Ensure queue exists

            Azure.Storage.Queues.Models.QueueProperties properties = await queueClient.GetPropertiesAsync();
            int messageCount = properties.ApproximateMessagesCount;
            resultLog.CurrentQueueDepth = messageCount;

            _logger.LogInformation("Queue '{QueueName}' current depth: {MessageCount}", _settings.QueueName, messageCount);

            if (messageCount > _settings.AlertThreshold)
            {
                _logger.LogWarning("Queue '{QueueName}' depth ({MessageCount}) exceeds threshold ({Threshold}). Sending alert.",
                    _settings.QueueName, messageCount, _settings.AlertThreshold);

                resultLog.AlertTriggered = true;
                var alertPayload = new { Body = $"Alert: Queue '{_settings.QueueName}' depth is {messageCount}, exceeding threshold of {_settings.AlertThreshold}." };
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
                _logger.LogInformation("Queue '{QueueName}' depth ({MessageCount}) is within threshold ({Threshold}). No alert sent.",
                    _settings.QueueName, messageCount, _settings.AlertThreshold);
                resultLog.AlertTriggered = false;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing queue '{QueueName}': {ErrorMessage}", _settings.QueueName, ex.Message);
            resultLog.Error = ex.Message;
        }
        finally
        {
            await StoreResultAsync(resultLog);
        }

        _logger.LogInformation("Queue monitoring finished for '{QueueName}'.", _settings.QueueName);
    }

    private async Task StoreResultAsync(ResultLogEntry resultLog)
    {
        try
        {
            BlobContainerClient containerClient = _blobServiceClient.GetBlobContainerClient(_settings.ResultsContainerName);
            await containerClient.CreateIfNotExistsAsync(PublicAccessType.None);

            string blobName = $"{resultLog.Timestamp:yyyyMMddHHmmssfff}_{_settings.QueueName}_status.json";
            string jsonResult = JsonSerializer.Serialize(resultLog, new JsonSerializerOptions { WriteIndented = true });

            BlobClient blobClient = containerClient.GetBlobClient(blobName);
            using var stream = new MemoryStream(Encoding.UTF8.GetBytes(jsonResult));
            await blobClient.UploadAsync(stream, overwrite: true);

            _logger.LogInformation("Successfully stored result to blob: {ContainerName}/{BlobName}", _settings.ResultsContainerName, blobName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to store result for queue '{QueueName}' to blob storage: {ErrorMessage}", _settings.QueueName, ex.Message);
            // Optionally, rethrow or handle critical storage failure if the function should fail overall
        }
    }
}

// Helper class for structured logging of results
public class ResultLogEntry
{
    public DateTime Timestamp { get; set; }
    public required string QueueName { get; set; }
    public int AlertThreshold { get; set; }
    public int CurrentQueueDepth { get; set; }
    public bool AlertTriggered { get; set; }
    public string? AlertUrl { get; set; }
    public bool? AlertSuccess { get; set; }
    public int? AlertStatusCode { get; set; }
    public string? AlertErrorMessage { get; set; }
    public string? Error { get; set; } // For general processing errors
}
```

---

**6. Build and Test Locally:**

```bash
dotnet build
func start
```
You should see logs in the console. Check your `queue-results` container in Azure Storage Explorer after a few minutes.

---

**7. Deploy to Azure using .NET CLI:**

First, ensure you have an existing Function App in Azure configured to use the .NET Isolated worker model and the correct .NET version (e.g., .NET 9). You can create one via the Azure Portal, Azure CLI, or ARM/Bicep templates.

**Azure CLI commands to create resources (if they don't exist):**

```bash
RESOURCE_GROUP="MyQueueMonitorRG"
LOCATION="eastus" # Choose your region
STORAGE_ACCOUNT_NAME="mystorageacc$(openssl rand -hex 3)" # Needs to be globally unique
FUNCTION_APP_NAME="MyQueueMonitorApp-$(openssl rand -hex 3)" # Needs to be globally unique
QUEUE_NAME="my-app-queue" # From your local.settings.json or desired
RESULTS_CONTAINER_NAME="queue-results"

# Create Resource Group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Storage Account
az storage account create --name $STORAGE_ACCOUNT_NAME --location $LOCATION --resource-group $RESOURCE_GROUP --sku Standard_LRS
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --query connectionString --output tsv)

# Create Storage Queue
az storage queue create --name $QUEUE_NAME --account-name $STORAGE_ACCOUNT_NAME --connection-string $STORAGE_CONNECTION_STRING

# Create Blob Container
az storage container create --name $RESULTS_CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --connection-string $STORAGE_CONNECTION_STRING

# Create Function App
az functionapp create --resource-group $RESOURCE_GROUP \
  --name $FUNCTION_APP_NAME \
  --storage-account $STORAGE_ACCOUNT_NAME \
  --consumption-plan-location $LOCATION \
  --runtime dotnet-isolated \
  --runtime-version 9.0 \ # Or your specific .NET 9 version, check `az functionapp list-runtimes`
  --functions-version 4 \
  --os-type Windows # or Linux

# Configure Application Settings for the deployed Function App
az functionapp config appsettings set --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP \
  --settings "AzureWebJobsStorage=$STORAGE_CONNECTION_STRING" \
             "APP_QUEUE_NAME=$QUEUE_NAME" \
             "APP_ALERT_THRESHOLD=50" \
             "APP_ALERT_URL=https://book.univrs.io/MarkD" \
             "APP_RESULTS_CONTAINER_NAME=$RESULTS_CONTAINER_NAME" \
             "FUNCTIONS_EXTENSION_VERSION=~4" # Ensure v4 host
```
*Adjust `runtime-version` if necessary. Check available runtimes with `az functionapp list-runtimes --os <Linux_or_Windows> | grep dotnet-isolated`.*

**Deploy the function code:**

Navigate to your project directory (`QueueMonitorApp`).

```bash
# Ensure you are logged into Azure CLI and have the correct subscription selected
# az login
# az account set --subscription "Your Subscription ID"

# Publish the function
func azure functionapp publish $FUNCTION_APP_NAME --csharp
```
The `--csharp` flag might not be strictly necessary if the project type is correctly inferred, but it doesn't hurt.

---

**8. Monitor in Azure Portal:**

Go to your Function App in the Azure Portal. Check the "Monitor" section for invocations and logs. Verify that JSON files are being created in your `queue-results` blob container.

---

**Robustness & Modularity Achieved:**

*   **Configuration:** Settings are externalized and managed through `IOptions<FunctionSettings>`.
*   **Dependency Injection:** Services (`HttpClientFactory`, `QueueServiceClient`, `BlobServiceClient`, `ILogger`) are injected, making the function testable and components swappable.
*   **Error Handling:** `try-catch` blocks are used for external calls (queue, HTTP, blob), and errors are logged. The `finally` block ensures results are attempted to be stored even if an error occurs during queue processing or alerting.
*   **Latest SDKs:** Uses modern `Azure.*` SDKs.
*   **Structured Logging:** Provides informative log messages. The `ResultLogEntry` class ensures a consistent structure for the data being saved.
*   **Idempotency (for result storage):** By creating a new blob with a timestamp in its name for each run, we avoid conflicts and ensure each function execution's outcome is recorded.
*   **Clarity:** Code is more organized and easier to read.

