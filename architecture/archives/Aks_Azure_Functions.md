#### Azure Functions using C# 12 with .NET 9.0

Targeting the Azure Functions V4 isolated worker model. We'll also create an Azure DevOps YAML pipeline for CI/CD.



**Step 1: Prerequisites (Development Environment)**

1.  **.NET 9 SDK:** Install the .NET 9 SDK (Preview) from [dotnet.microsoft.com](https://dotnet.microsoft.com/download/dotnet/9.0).
2.  **Azure Functions Core Tools:** Install/update to the latest v4 (`npm install -g azure-functions-core-tools@4 --unsafe-perm true`).
3.  **IDE:** Visual Studio 2022 (with .NET 9 preview workloads) or VS Code with C# Dev Kit.
4.  **Azure CLI:** Installed and logged in (`az login`).
5.  **Azure DevOps Project:** An Azure DevOps project where you can create repositories and pipelines.

---

**Step 2: Create Azure Function App Resources and Managed Identities**

This step is identical to the Go solution (Step 2 and 3 in the previous response). You'll need two Function Apps (e.g., `checksaqueuefuncapp-dev`, `increasehpafuncapp-dev` for dev, and similar for prod) with system-assigned managed identities.

**Make sure you have done the following from the previous GoLang solution steps:**
*   Created the two Function Apps (e.g., `checksaqueuefuncapp-dev`, `increasehpafuncapp-dev`).
*   Enabled System-Assigned Managed Identities for both.
*   Assigned the necessary IAM roles:
    *   **`checksaqueuefuncapp-dev` MI:**
        *   "Storage Queue Data Reader" on the monitored Storage Account.
        *   "Storage Table Data Contributor" on the table `queuestatestore` within its *own* Function App's storage account (or a dedicated one for state).
    *   **`increasehpafuncapp-dev` MI:**
        *   "Azure Kubernetes Service Cluster Admin Role" on the `cdsaksclusterdev` AKS cluster in `rg-cds-optmz-dev`.
*   Create the `queuestatestore` table in the storage account used by `checksaqueuefuncapp-dev`.

---

**Step 3: Develop the C# Azure Functions**

We'll create two separate C# Function projects. It's good practice to put them in a single solution if you prefer.

**Project Structure (Example):**
```
/AzureAksHpaScaler
  /src
    /CheckSaQueueFunction
      CheckSaQueueFunction.csproj
      CheckSaQueueTimer.cs
      StateEntity.cs
      host.json
      local.settings.json.template  (gitignored, copy to local.settings.json)
    /IncreaseHpaAksFunction
      IncreaseHpaAksFunction.csproj
      IncreaseHpaAksHttp.cs
      host.json
      local.settings.json.template
  AzureAksHpaScaler.sln (optional)
  azure-pipelines.yml
  README.md
```

**A. `CheckSaQueueFunction` Project**

1.  **Create the Project:**
    ```bash
    mkdir -p AzureAksHpaScaler/src/CheckSaQueueFunction
    cd AzureAksHpaScaler/src/CheckSaQueueFunction
    dotnet new func -n CheckSaQueueFunction  --framework net9.0
    # This creates a sample HttpTrigger function, we'll replace it.
    # Add necessary packages
    dotnet add package Azure.Identity
    dotnet add package Azure.Storage.Queues
    dotnet add package Azure.Data.Tables
    dotnet add package Microsoft.Azure.Functions.Worker.Extensions.Timer
    dotnet add package Microsoft.Azure.Functions.Worker.Sdk --version 1.17.0 # Or latest
    dotnet add package Microsoft.Extensions.Logging.Console # For local console logging
    ```

2.  **`StateEntity.cs`:**
    ```csharp
    using Azure;
    using Azure.Data.Tables;
    using System;

    namespace CheckSaQueueFunction;

    public class StateEntity : ITableEntity
    {
        public string PartitionKey { get; set; } // e.g., MonitoredQueueName
        public string RowKey { get; set; }       // e.g., "latest"
        public DateTimeOffset? Timestamp { get; set; }
        public ETag ETag { get; set; }

        public int LastDepth { get; set; }
        public DateTime LastCheckTime { get; set; }
    }
    ```

3.  **`CheckSaQueueTimer.cs`:**
    ```csharp
    using Azure.Data.Tables;
    using Azure.Identity;
    using Azure.Storage.Queues;
    using Microsoft.Azure.Functions.Worker;
    using Microsoft.Extensions.Logging;
    using System;
    using System.Net.Http;
    using System.Text.Json;
    using System.Threading.Tasks;

    namespace CheckSaQueueFunction;

    public class CheckSaQueueTimer
    {
        private readonly ILogger<CheckSaQueueTimer> _logger;
        private readonly HttpClient _httpClient;

        // Using primary constructor (C# 12) for dependency injection
        public CheckSaQueueTimer(ILogger<CheckSaQueueTimer> logger, IHttpClientFactory httpClientFactory)
        {
            _logger = logger;
            _httpClient = httpClientFactory.CreateClient();
        }

        [Function("check_sa_queue")]
        public async Task Run([TimerTrigger("0 */1 * * * *")] TimerInfo myTimer) // Runs every 1 minute
        {
            _logger.LogInformation($"C# Timer trigger function 'check_sa_queue' executed at: {DateTime.Now}");

            var monitoredStorageAccountName = Environment.GetEnvironmentVariable("MONITORED_STORAGE_ACCOUNT_NAME");
            var monitoredQueueName = Environment.GetEnvironmentVariable("MONITORED_QUEUE_NAME");
            var depthThresholdStr = Environment.GetEnvironmentVariable("DEPTH_THRESHOLD");
            var growthRateThresholdPercentStr = Environment.GetEnvironmentVariable("GROWTH_RATE_THRESHOLD_PERCENT");
            var growthCheckIntervalSecondsStr = Environment.GetEnvironmentVariable("GROWTH_CHECK_INTERVAL_SECONDS");
            var scalerFunctionUrl = Environment.GetEnvironmentVariable("SCALER_FUNCTION_URL");
            var scalerFunctionKey = Environment.GetEnvironmentVariable("SCALER_FUNCTION_KEY"); // Optional for function key auth

            var stateStorageAccountName = Environment.GetEnvironmentVariable("STATE_STORAGE_ACCOUNT_NAME");
            var stateTableName = Environment.GetEnvironmentVariable("STATE_TABLE_NAME") ?? "queuestatestore";

            if (string.IsNullOrEmpty(monitoredStorageAccountName) || string.IsNullOrEmpty(monitoredQueueName) ||
                string.IsNullOrEmpty(depthThresholdStr) || string.IsNullOrEmpty(growthRateThresholdPercentStr) ||
                string.IsNullOrEmpty(growthCheckIntervalSecondsStr) || string.IsNullOrEmpty(scalerFunctionUrl) ||
                string.IsNullOrEmpty(stateStorageAccountName))
            {
                _logger.LogError("Error: Missing one or more required environment variables for queue check.");
                return;
            }

            if (!int.TryParse(depthThresholdStr, out var depthThreshold) ||
                !double.TryParse(growthRateThresholdPercentStr, out var growthRateThresholdPercent) ||
                !int.TryParse(growthCheckIntervalSecondsStr, out var growthCheckIntervalSeconds))
            {
                _logger.LogError("Error parsing threshold numeric values.");
                return;
            }

            try
            {
                var credential = new DefaultAzureCredential();

                // 1. Get Current Queue Depth
                var queueServiceUri = new Uri($"https://{monitoredStorageAccountName}.queue.core.windows.net/");
                var queueServiceClient = new QueueServiceClient(queueServiceUri, credential);
                var queueClient = queueServiceClient.GetQueueClient(monitoredQueueName);

                var properties = await queueClient.GetPropertiesAsync();
                var currentDepth = properties.Value.ApproximateMessagesCount;
                _logger.LogInformation($"Queue: {monitoredQueueName}, Current Depth: {currentDepth}");

                // 2. Get Previous State from Table Storage
                var tableServiceUri = new Uri($"https://{stateStorageAccountName}.table.core.windows.net/");
                var tableServiceClient = new TableServiceClient(tableServiceUri, credential);
                var tableClient = tableServiceClient.GetTableClient(stateTableName);
                await tableClient.CreateIfNotExistsAsync(); // Ensure table exists

                string partitionKey = monitoredQueueName;
                string rowKey = "latest";
                StateEntity previousState = null;
                int previousDepth = 0;
                DateTime lastCheckTime = DateTime.MinValue;

                try
                {
                    var entityResponse = await tableClient.GetEntityAsync<StateEntity>(partitionKey, rowKey);
                    previousState = entityResponse.Value;
                    previousDepth = previousState.LastDepth;
                    lastCheckTime = previousState.LastCheckTime;
                    _logger.LogInformation($"Retrieved previous state: Depth={previousDepth}, Time={lastCheckTime:O}");
                }
                catch (Azure.RequestFailedException ex) when (ex.Status == 404)
                {
                    _logger.LogInformation($"No previous state found for {monitoredQueueName} (first run or state cleared).");
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Warn: Error getting previous state from table. Proceeding without growth rate check for this run.");
                }

                // 3. Update State in Table Storage
                var newState = new StateEntity
                {
                    PartitionKey = partitionKey,
                    RowKey = rowKey,
                    LastDepth = currentDepth,
                    LastCheckTime = DateTime.UtcNow
                };
                await tableClient.UpsertEntityAsync(newState, TableUpdateMode.Replace);
                _logger.LogInformation("Successfully updated state in table storage.");

                // 4. Check Depth Threshold
                if (currentDepth <= depthThreshold)
                {
                    _logger.LogInformation($"Depth {currentDepth} is not above threshold {depthThreshold}. No action.");
                    return;
                }
                _logger.LogInformation($"Depth {currentDepth} IS ABOVE threshold {depthThreshold}.");

                // 5. Check Growth Rate
                bool triggerScale = true; // Default to trigger if depth threshold is met
                if (previousState != null && lastCheckTime != DateTime.MinValue)
                {
                    var timeSinceLastCheck = DateTime.UtcNow.Subtract(lastCheckTime);
                    if (timeSinceLastCheck.TotalSeconds >= growthCheckIntervalSeconds)
                    {
                        var depthIncrease = currentDepth - previousDepth;
                        double currentGrowthRatePercent = 0;

                        if (previousDepth > 0)
                        {
                            currentGrowthRatePercent = ((double)depthIncrease / previousDepth) * 100;
                        }
                        else if (currentDepth > 0) // Grew from 0
                        {
                            currentGrowthRatePercent = 100.0; // Or a very large number
                        }

                        _logger.LogInformation($"Growth check: PreviousDepth={previousDepth}, CurrentDepth={currentDepth}, Increase={depthIncrease}, TimeSinceLastCheck={timeSinceLastCheck.TotalSeconds:F2}s");
                        _logger.LogInformation($"Calculated growth rate: {currentGrowthRatePercent:F2}%");

                        if (currentGrowthRatePercent <= growthRateThresholdPercent)
                        {
                            _logger.LogInformation($"Growth rate {currentGrowthRatePercent:F2}% is not above threshold {growthRateThresholdPercent:F2}%. No action based on growth.");
                            triggerScale = false; // Override trigger if growth doesn't meet criteria
                        }
                        else
                        {
                             _logger.LogInformation($"Growth rate {currentGrowthRatePercent:F2}% IS ABOVE threshold {growthRateThresholdPercent:F2}%.");
                        }
                    }
                    else
                    {
                        _logger.LogInformation($"Skipping growth rate check: Not enough time since last check ({timeSinceLastCheck.TotalSeconds:F2}s < {growthCheckIntervalSeconds}s). Depth threshold met, proceeding to scale.");
                        // triggerScale remains true by default
                    }
                }
                else
                {
                     _logger.LogInformation("No previous state for growth rate calculation. Depth threshold met, proceeding to scale.");
                     // triggerScale remains true by default
                }


                if (!triggerScale)
                {
                    _logger.LogInformation("Scaling conditions (depth + growth rate) not fully met. No action.");
                    return;
                }

                // 6. Call Scaler Function
                _logger.LogInformation($"Conditions met. Calling scaler function: {scalerFunctionUrl}");
                var request = new HttpRequestMessage(HttpMethod.Post, scalerFunctionUrl);
                if (!string.IsNullOrEmpty(scalerFunctionKey))
                {
                    request.Headers.Add("x-functions-key", scalerFunctionKey);
                }
                // Can add a simple JSON body if needed by the scaler
                // var payload = new { queueName = monitoredQueueName, currentDepth = currentDepth };
                // request.Content = new StringContent(JsonSerializer.Serialize(payload), System.Text.Encoding.UTF8, "application/json");

                var response = await _httpClient.SendAsync(request);
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation($"Scaler function called successfully. Status: {response.StatusCode}");
                }
                else
                {
                    var responseContent = await response.Content.ReadAsStringAsync();
                    _logger.LogError($"Scaler function call failed. Status: {response.StatusCode}. Response: {responseContent}");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An error occurred in check_sa_queue function.");
            }
        }
    }
    ```

4.  **`Program.cs` (for .NET Isolated Worker DI setup):**
    ```csharp
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Hosting;
    using Microsoft.Extensions.Logging;

    var host = new HostBuilder()
        .ConfigureFunctionsWebApplication()
        .ConfigureServices(services =>
        {
            services.AddHttpClient(); // For IHttpClientFactory
            // Add other services here if needed
            services.AddLogging(loggingBuilder => // Optional: configure logging further
            {
                loggingBuilder.AddConsole(); // Example: Add console logger
            });
        })
        .Build();

    host.Run();
    ```

5.  **`host.json`:**
    ```json
    {
      "version": "2.0",
      "logging": {
        "applicationInsights": {
          "samplingSettings": {
            "isEnabled": true,
            "excludedTypes": "Request"
          }
        },
        "logLevel": {
          "Default": "Information", // Or "Warning", "Error"
          "Function.CheckSaQueueTimer": "Information", // Specific log level for your function
          "Host.Results": "Information"
        }
      },
      "extensionBundle": { // Important for bindings like TimerTrigger
        "id": "Microsoft.Azure.Functions.ExtensionBundle",
        "version": "[4.*, 5.0.0)" // Check for the latest compatible version
      }
    }
    ```

6.  **`local.settings.json.template` (DO NOT COMMIT `local.settings.json` with secrets):**
    ```json
    {
      "IsEncrypted": false,
      "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true", // Or your actual Function App storage
        "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
        "MONITORED_STORAGE_ACCOUNT_NAME": "yourtargetstorageaccount",
        "MONITORED_QUEUE_NAME": "yourtargetqueue",
        "DEPTH_THRESHOLD": "100",
        "GROWTH_RATE_THRESHOLD_PERCENT": "50", // 50%
        "GROWTH_CHECK_INTERVAL_SECONDS": "300", // 5 minutes
        "SCALER_FUNCTION_URL": "http://localhost:7072/api/increase_hpa_aks", // Local URL for increase_hpa_aks
        "SCALER_FUNCTION_KEY": "", // Optional: key for local scaler function if authLevel=function
        "STATE_STORAGE_ACCOUNT_NAME": "yourfunctionappstorage", // Storage for the state table
        "STATE_TABLE_NAME": "queuestatestore"
        // For Managed Identity locally (if not using VS Azure Service Auth or similar):
        // "AZURE_CLIENT_ID": "your-mi-client-id",
        // "AZURE_TENANT_ID": "your-tenant-id",
        // "AZURE_CLIENT_SECRET": "if-using-sp-locally-for-mi-dev" (not for deployed MI)
      }
    }
    ```
    *Copy this to `local.settings.json` and fill in your values for local testing.*

**B. `IncreaseHpaAksFunction` Project**

1.  **Create the Project:**
    ```bash
    mkdir -p AzureAksHpaScaler/src/IncreaseHpaAksFunction
    cd AzureAksHpaScaler/src/IncreaseHpaAksFunction
    dotnet new func -n IncreaseHpaAksFunction --worker-runtime dotnet-isolated --target-framework net9.0
    # Add necessary packages
    dotnet add package Azure.Identity
    dotnet add package Azure.ResourceManager.ContainerService
    # For Kubernetes client:
    dotnet add package KubernetesClient --version 13.0.11 # Or latest stable
    # For JSON handling in HttpTrigger input/output for .NET Isolated:
    dotnet add package Microsoft.Azure.Functions.Worker.Extensions.Http
    dotnet add package Microsoft.Azure.Functions.Worker.Sdk --version 1.17.0 # Or latest
    dotnet add package Microsoft.Extensions.Logging.Console
    ```

2.  **`IncreaseHpaAksHttp.cs`:**

```csharp
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.ContainerService; // Required for ManagedClusterCollection
using Azure.ResourceManager.Resources; // <<<< ADD THIS USING DIRECTIVE
using k8s;
using k8s.Models; // For V1Patch and V2HorizontalPodAutoscaler etc.
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System;
using System.IO;
using System.Linq;
using System.Net;
// using System.Text; // Not directly used now with string patch
using System.Threading.Tasks;

namespace IncreaseHpaAksFunction;

public class IncreaseHpaAksHttp
{
    private readonly ILogger<IncreaseHpaAksHttp> _logger;

    public IncreaseHpaAksHttp(ILogger<IncreaseHpaAksHttp> logger)
    {
        _logger = logger;
    }

    [Function("increase_hpa_aks")]
    public async Task<HttpResponseData> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
    {
        _logger.LogInformation("C# HTTP trigger function 'increase_hpa_aks' processed a request.");

        var aksResourceGroup = Environment.GetEnvironmentVariable("AKS_RESOURCE_GROUP");
        var aksClusterName = Environment.GetEnvironmentVariable("AKS_CLUSTER_NAME");
        var targetHpaName = Environment.GetEnvironmentVariable("TARGET_HPA_NAME");
        var targetHpaNamespace = Environment.GetEnvironmentVariable("TARGET_HPA_NAMESPACE");
        var increaseMaxByStr = Environment.GetEnvironmentVariable("INCREASE_MAX_BY_COUNT");
        var azureSubscriptionId = Environment.GetEnvironmentVariable("AZURE_SUBSCRIPTION_ID");

        if (string.IsNullOrEmpty(aksResourceGroup) || string.IsNullOrEmpty(aksClusterName) ||
            string.IsNullOrEmpty(targetHpaName) || string.IsNullOrEmpty(targetHpaNamespace) ||
            string.IsNullOrEmpty(increaseMaxByStr) || string.IsNullOrEmpty(azureSubscriptionId))
        {
            _logger.LogError("Error: Missing one or more required environment variables for HPA scaling.");
            var badResp = req.CreateResponse(HttpStatusCode.BadRequest);
            await badResp.WriteStringAsync("Error: Missing environment variables.");
            return badResp;
        }

        if (!int.TryParse(increaseMaxByStr, out var increaseMaxBy) || increaseMaxBy <= 0)
        {
            _logger.LogError($"Error: Invalid INCREASE_MAX_BY_COUNT value: {increaseMaxByStr}. Must be a positive integer.");
            var badNumResp = req.CreateResponse(HttpStatusCode.BadRequest);
            await badNumResp.WriteStringAsync("Error: Invalid INCREASE_MAX_BY_COUNT.");
            return badNumResp;
        }

        try
        {
            var credential = new DefaultAzureCredential();
            var armClient = new ArmClient(credential, azureSubscriptionId);

            // 1. Get AKS Admin Kubeconfig
            ContainerServiceManagedClusterResource managedCluster;
            try
            {
                var rgResourceId = ResourceGroupResource.CreateResourceIdentifier(azureSubscriptionId, aksResourceGroup);
                ResourceGroupResource resourceGroup = armClient.GetResourceGroupResource(rgResourceId);
                ContainerServiceManagedClusterCollection clusterCollection = resourceGroup.GetContainerServiceManagedClusters();
                
                Azure.Response<ContainerServiceManagedClusterResource> clusterGetResponse = await clusterCollection.GetAsync(aksClusterName);
                // GetAsync throws RequestFailedException on 404, so no need to check clusterGetResponse.HasValue if it succeeds
                managedCluster = clusterGetResponse.Value;
            }
            catch (Azure.RequestFailedException ex) when (ex.Status == (int)HttpStatusCode.NotFound)
            {
                _logger.LogError(ex, $"AKS cluster '{aksClusterName}' not found in resource group '{aksResourceGroup}'.");
                var notFoundResp = req.CreateResponse(HttpStatusCode.NotFound);
                await notFoundResp.WriteStringAsync("AKS Cluster not found.");
                return notFoundResp;
            }
            catch (Exception ex)
            {
                 _logger.LogError(ex, $"Error retrieving AKS cluster '{aksClusterName}'.");
                var errResp = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errResp.WriteStringAsync($"Error retrieving AKS cluster: {ex.Message}");
                return errResp;
            }
            
            var accessProfile = await managedCluster.GetAccessProfileAsync("clusterAdmin");
            var kubeconfigBytes = accessProfile.Value.KubeConfig;

            if (kubeconfigBytes == null || kubeconfigBytes.Length == 0)
            {
                _logger.LogError($"No kubeconfig returned for AKS cluster {aksClusterName}");
                var errResp = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errResp.WriteStringAsync("Failed to retrieve kubeconfig.");
                return errResp;
            }

            // 2. Create Kubernetes Client from Kubeconfig
            KubernetesClientConfiguration k8sConfig;
            using (var stream = new MemoryStream(kubeconfigBytes))
            {
                k8sConfig = KubernetesClientConfiguration.BuildConfigFromConfigFile(stream);
            }
            var k8sClient = new Kubernetes(k8sConfig);

            // 3. Get and Patch HPA (assuming autoscaling/v2 API)
            V2HorizontalPodAutoscaler hpa;
            try
            {
                hpa = await k8sClient.AutoscalingV2.ReadNamespacedHorizontalPodAutoscalerAsync(targetHpaName, targetHpaNamespace);
            }
            catch (k8s.Autorest.HttpOperationException ex) when (ex.Response.StatusCode == HttpStatusCode.NotFound)
            {
                _logger.LogError(ex, $"HPA (autoscaling/v2) '{targetHpaName}' not found in namespace '{targetHpaNamespace}'.");
                var notFoundHpa = req.CreateResponse(HttpStatusCode.NotFound);
                await notFoundHpa.WriteStringAsync($"HPA (autoscaling/v2) '{targetHpaName}' not found.");
                return notFoundHpa;
            }
             catch (Exception ex)
            {
                 _logger.LogError(ex, $"Error reading HPA (autoscaling/v2) '{targetHpaName}'.");
                var errResp = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errResp.WriteStringAsync($"Error reading HPA: {ex.Message}");
                return errResp;
            }

            var originalMaxReplicas = hpa.Spec.MaxReplicas;
            var newMaxReplicas = originalMaxReplicas + increaseMaxBy;
            var absoluteMaxReplicasStr = Environment.GetEnvironmentVariable("ABSOLUTE_MAX_REPLICAS");
            
            if (int.TryParse(absoluteMaxReplicasStr, out var absoluteMaxReplicas) && newMaxReplicas > absoluteMaxReplicas)
            {
                _logger.LogWarning($"Calculated newMaxReplicas ({newMaxReplicas}) exceeds ABSOLUTE_MAX_REPLICAS ({absoluteMaxReplicas}). Capping at {absoluteMaxReplicas}.");
                newMaxReplicas = absoluteMaxReplicas;
            }

            if (newMaxReplicas <= originalMaxReplicas)
            {
                 _logger.LogInformation($"HPA (autoscaling/v2) '{targetHpaName}' new MaxReplicas ({newMaxReplicas}) is not greater than original ({originalMaxReplicas}). No patch needed.");
                var okNoChange = req.CreateResponse(HttpStatusCode.OK);
                await okNoChange.WriteStringAsync($"HPA '{targetHpaName}' new MaxReplicas ({newMaxReplicas}) not greater than original. No change.");
                return okNoChange;
            }

            _logger.LogInformation($"Current HPA (autoscaling/v2) '{targetHpaName}' MaxReplicas: {originalMaxReplicas}. Attempting to set to: {newMaxReplicas}");

            string jsonPatchString = $"[{{\"op\": \"replace\", \"path\": \"/spec/maxReplicas\", \"value\": {newMaxReplicas}}}]";
            var patchPayload = new V1Patch(jsonPatchString, V1Patch.PatchType.JsonPatch);

            await k8sClient.AutoscalingV2.PatchNamespacedHorizontalPodAutoscalerAsync(patchPayload, targetHpaName, targetHpaNamespace);

            _logger.LogInformation($"Successfully patched HPA (autoscaling/v2) {targetHpaName} in namespace {targetHpaNamespace}. MaxReplicas changed from {originalMaxReplicas} to {newMaxReplicas}.");

            var response = req.CreateResponse(HttpStatusCode.OK);
            await response.WriteStringAsync($"Successfully updated HPA {targetHpaName}. New MaxReplicas: {newMaxReplicas}");
            return response;
        }
        catch (k8s.Autorest.HttpOperationException kex)
        {
             _logger.LogError(kex, $"Kubernetes API error. Status: {kex.Response?.StatusCode}. Content: {kex.Response?.Content}");
            var errResp = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errResp.WriteStringAsync($"Kubernetes API error: {kex.Message}");
            return errResp;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An unexpected error occurred in increase_hpa_aks function.");
            var errResp = req.CreateResponse(HttpStatusCode.InternalServerError);
            await errResp.WriteStringAsync($"An internal error occurred: {ex.Message}");
            return errResp;
        }
    }
}
```
*Note: The `Azure.ResourceManager.ContainerService.ManagedClusterResource.GetAdminCredentialsAsync()` is a more modern way to get credentials than the older `ManagedClustersOperationsExtensions.ListClusterAdminCredentialsAsync`.**The HPA patch should ideally use `V2HorizontalPodAutoscaler` if your HPA is `autoscaling/v2`. The KubernetesClient library has models for `V2HorizontalPodAutoscaler`. Let's adjust to ensure we use the correct HPA version type. If your HPAs are `autoscaling/v2beta2` or `v1`, you'd use those specific types.* The code above will attempt to patch `V1HorizontalPodAutoscaler`. **It should be `V2HorizontalPodAutoscaler` for modern HPAs.** I'll correct it to use `ReadNamespacedHorizontalPodAutoscalerAsync` which typically refers to `autoscaling/v1`. For `autoscaling/v2`, you'd use `k8sClient.AutoscalingV2.ReadNamespacedHorizontalPodAutoscalerAsync`. Let's assume `autoscaling/v2` is preferred.
    **Corrected HPA part in `IncreaseHpaAksHttp.cs` for `autoscaling/v2`:**

```csharp
    // ... inside IncreaseHpaAksHttp.Run method ...
    // 3. Get and Patch HPA (using autoscaling/v2 API)
    var hpa = await k8sClient.AutoscalingV2.ReadNamespacedHorizontalPodAutoscalerAsync(targetHpaName, targetHpaNamespace); // For autoscaling/v2
    if (hpa == null)
    {
        _logger.LogError($"HPA '{targetHpaName}' (autoscaling/v2) not found in namespace '{targetHpaNamespace}'.");
        var notFoundHpa = req.CreateResponse(HttpStatusCode.NotFound);
        await notFoundHpa.WriteStringAsync($"HPA '{targetHpaName}' (autoscaling/v2) not found.");
        return notFoundHpa;
    }

    var originalMaxReplicas = hpa.Spec.MaxReplicas;
    var newMaxReplicas = originalMaxReplicas + increaseMaxBy;
    // ... (rest of the capping logic remains the same) ...

    _logger.LogInformation($"Current HPA '{targetHpaName}' (autoscaling/v2) MaxReplicas: {originalMaxReplicas}. Attempting to set to: {newMaxReplicas}");

    // Create a new HPA object with the updated maxReplicas for replacement, or use JSON Patch
    // Using JSON Patch is often more robust for partial updates:
    var patchDoc = new JsonPatchDocument<V2HorizontalPodAutoscaler>();
    patchDoc.Replace(e => e.Spec.MaxReplicas, newMaxReplicas);

    var patchContent = new V1Patch(patchDoc, V1Patch.PatchType.JsonPatch); // Ensure V1Patch is compatible with how you build the patch content.
                                                                          // Simpler for single field:
    var simplePatch = new V1Patch(
        new { spec = new { maxReplicas = newMaxReplicas } }, // This structure depends on how the K8s API expects the patch body for `strategic-merge-patch` or if you use `application/json-patch+json`
        V1Patch.PatchType.StrategicMergePatch); // Or JsonPatch with proper path

    // For JSON Patch type (more explicit):
    var jsonPatchPayload = new V1Patch(
        $"[{{\"op\": \"replace\", \"path\": \"/spec/maxReplicas\", \"value\": {newMaxReplicas}}}]",
        V1Patch.PatchType.JsonPatch
    );

    await k8sClient.AutoscalingV2.PatchNamespacedHorizontalPodAutoscalerAsync(jsonPatchPayload, targetHpaName, targetHpaNamespace);
    _logger.LogInformation($"Successfully patched HPA (autoscaling/v2) {targetHpaName} in namespace {targetHpaNamespace}. MaxReplicas changed from {originalMaxReplicas} to {newMaxReplicas}.");
    // ...
    ```
    The Kubernetes client patch methods can be tricky. Using `ReplaceNamespacedHorizontalPodAutoscalerAsync` with a modified full HPA object is also an option but can lead to conflicts if other controllers modify the HPA. `PatchNamespaced...` is generally preferred. The `jsonPatchPayload` above is a common way.

3.  **`Program.cs` (similar DI setup):**

```csharp
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication()
    .ConfigureServices(services => {
        // No HttpClient needed here unless the function itself makes outbound calls
         services.AddLogging(loggingBuilder =>
        {
            loggingBuilder.AddConsole();
        });
    })
    .Build();

host.Run();
```

4.  **`host.json` (similar to the other function):**
    ```json
    {
      "version": "2.0",
      "logging": {
        "applicationInsights": {
          "samplingSettings": {
            "isEnabled": true,
            "excludedTypes": "Request"
          }
        },
        "logLevel": {
          "Default": "Information",
          "Function.IncreaseHpaAksHttp": "Information",
          "Host.Results": "Information"
        }
      },
      "extensionBundle": {
        "id": "Microsoft.Azure.Functions.ExtensionBundle",
        "version": "[4.*, 5.0.0)"
      }
    }
    ```

5.  **`local.settings.json.template`:**
    ```json
    {
      "IsEncrypted": false,
      "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
        "AKS_RESOURCE_GROUP": "rg-cds-optmz-dev",
        "AKS_CLUSTER_NAME": "cdsaksclusterdev",
        "TARGET_HPA_NAME": "your-hpa-name-in-aks",
        "TARGET_HPA_NAMESPACE": "default", // Or your HPA's namespace
        "INCREASE_MAX_BY_COUNT": "2",
        "ABSOLUTE_MAX_REPLICAS": "20", // Safety cap for max replicas
        "AZURE_SUBSCRIPTION_ID": "your-azure-subscription-id"
        // "AZURE_CLIENT_ID": "your-mi-client-id", (for local dev if needed)
        // "AZURE_TENANT_ID": "your-tenant-id",
        // "AZURE_CLIENT_SECRET": "..."
      }
    }
    ```

---

**Step 4: Azure DevOps YAML Pipeline (`azure-pipelines.yml`)**

Place this file in the root of your `AzureAksHpaScaler` repository.

```yaml
trigger:
  branches:
    include:
      - dev
      - main # This will be 'refs/heads/main' if your default branch is main

variables:
  # Solution path or individual project paths if not using a solution
  # checkSaQueueProj: 'src/CheckSaQueueFunction/CheckSaQueueFunction.csproj'
  # increaseHpaAksProj: 'src/IncreaseHpaAksFunction/IncreaseHpaAksFunction.csproj'
  buildPlatform: 'Any CPU'
  buildConfiguration: 'Release'
  dotnetSdkVersion: '9.0.x' # Ensure Azure DevOps Hosted Agent has this SDK or install it

  # --- Dev Environment Variables ---
  # These can also be set in a Variable Group linked to the 'dev' environment in Azure DevOps
  DEV_CHECK_FUNC_APP_NAME: 'checksaqueuefuncapp-dev' # Your DEV checker function app name
  DEV_SCALE_FUNC_APP_NAME: 'increasehpafuncapp-dev' # Your DEV scaler function app name
  DEV_SCALER_FUNCTION_URL: 'https://increasehpafuncapp-dev.azurewebsites.net/api/increase_hpa_aks' # Get this after first deploy or from portal
  # Add other DEV specific app settings here or use Azure App Configuration / Key Vault

  # --- Prod Environment Variables ---
  PROD_CHECK_FUNC_APP_NAME: 'checksaqueuefuncapp-prod'
  PROD_SCALE_FUNC_APP_NAME: 'increasehpafuncapp-prod'
  PROD_SCALER_FUNCTION_URL: 'https://increasehpafuncapp-prod.azurewebsites.net/api/increase_hpa_aks'
  # Add other PROD specific app settings

stages:
- stage: Build
  displayName: 'Build .NET Functions'
  jobs:
  - job: BuildFunctions
    displayName: 'Build and Package Functions'
    pool:
      vmImage: 'windows-latest' # Or 'ubuntu-latest', ensure .NET 9 SDK compatibility
    steps:
    - task: UseDotNet@2
      displayName: 'Use .NET SDK $(dotnetSdkVersion)'
      inputs:
        packageType: 'sdk'
        version: '$(dotnetSdkVersion)'
        installationPath: $(Agent.ToolsDirectory)/dotnet # Ensure it's on PATH

    - script: echo "Restoring and Building CheckSaQueueFunction"
      displayName: 'Log CheckSaQueue Build Start'
    - task: DotNetCoreCLI@2
      displayName: 'Restore CheckSaQueueFunction'
      inputs:
        command: 'restore'
        projects: 'src/CheckSaQueueFunction/CheckSaQueueFunction.csproj'
        feedsToUse: 'select'
    - task: DotNetCoreCLI@2
      displayName: 'Build CheckSaQueueFunction'
      inputs:
        command: 'build'
        projects: 'src/CheckSaQueueFunction/CheckSaQueueFunction.csproj'
        arguments: '--configuration $(buildConfiguration) --no-restore'
    - task: DotNetCoreCLI@2
      displayName: 'Publish CheckSaQueueFunction'
      inputs:
        command: 'publish'
        publishWebProjects: false # Important for function apps
        projects: 'src/CheckSaQueueFunction/CheckSaQueueFunction.csproj'
        arguments: '--configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)/CheckSaQueueFunction --no-build --runtime linux-x64 --self-contained false' # Adjust runtime if needed, self-contained false for isolated
        zipAfterPublish: false # We will archive later

    - script: echo "Restoring and Building IncreaseHpaAksFunction"
      displayName: 'Log IncreaseHpaAks Build Start'
    - task: DotNetCoreCLI@2
      displayName: 'Restore IncreaseHpaAksFunction'
      inputs:
        command: 'restore'
        projects: 'src/IncreaseHpaAksFunction/IncreaseHpaAksFunction.csproj'
        feedsToUse: 'select'
    - task: DotNetCoreCLI@2
      displayName: 'Build IncreaseHpaAksFunction'
      inputs:
        command: 'build'
        projects: 'src/IncreaseHpaAksFunction/IncreaseHpaAksFunction.csproj'
        arguments: '--configuration $(buildConfiguration) --no-restore'
    - task: DotNetCoreCLI@2
      displayName: 'Publish IncreaseHpaAksFunction'
      inputs:
        command: 'publish'
        publishWebProjects: false
        projects: 'src/IncreaseHpaAksFunction/IncreaseHpaAksFunction.csproj'
        arguments: '--configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)/IncreaseHpaAksFunction --no-build --runtime linux-x64 --self-contained false'
        zipAfterPublish: false

    - task: ArchiveFiles@2
      displayName: 'Archive CheckSaQueueFunction Files'
      inputs:
        rootFolderOrFile: '$(Build.ArtifactStagingDirectory)/CheckSaQueueFunction'
        includeRootFolder: false
        archiveType: 'zip'
        archiveFile: '$(Build.ArtifactStagingDirectory)/CheckSaQueueFunction.zip'
        replaceExistingArchive: true

    - task: ArchiveFiles@2
      displayName: 'Archive IncreaseHpaAksFunction Files'
      inputs:
        rootFolderOrFile: '$(Build.ArtifactStagingDirectory)/IncreaseHpaAksFunction'
        includeRootFolder: false
        archiveType: 'zip'
        archiveFile: '$(Build.ArtifactStagingDirectory)/IncreaseHpaAksFunction.zip'
        replaceExistingArchive: true

    - task: PublishBuildArtifacts@1
      displayName: 'Publish All Function Artifacts'
      inputs:
        PathtoPublish: '$(Build.ArtifactStagingDirectory)'
        ArtifactName: 'functionapps' # Contains the two zip files

- stage: DeployDev
  displayName: 'Deploy to Dev Environment'
  dependsOn: Build
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/dev'))
  jobs:
  - deployment: DeployFunctionsDev
    displayName: 'Deploy Functions to Dev'
    environment: 'YourDevEnvironmentNameInAzureDevOps' # Create this in Azure DevOps Environments
    pool:
      vmImage: 'windows-latest'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: DownloadBuildArtifacts@1
            displayName: 'Download Artifacts'
            inputs:
              buildType: 'current'
              downloadType: 'single'
              artifactName: 'functionapps'
              downloadPath: '$(System.ArtifactsDirectory)'

          - task: AzureFunctionApp@2
            displayName: 'Deploy CheckSaQueueFunction to Dev'
            inputs:
              azureSubscription: 'YourAzureServiceConnectionName' # Needs Contributor on Function App & its App Settings
              appType: 'functionAppLinux' # Or 'functionApp' for Windows
              appName: $(DEV_CHECK_FUNC_APP_NAME)
              package: '$(System.ArtifactsDirectory)/functionapps/CheckSaQueueFunction.zip'
              runtimeStack: 'DOTNET-ISOLATED|9.0' # Verify exact string for .NET 9 isolated
              deploymentMethod: 'auto' # Or 'zipDeploy' or 'runFromPackage'
              # App settings can be managed in Azure Portal, via ARM templates, or here:
              # Note: Secrets should be in Azure Key Vault or pipeline secrets/variable groups
              appSettings: >-
                -MONITORED_STORAGE_ACCOUNT_NAME your_dev_storage_account_name
                -MONITORED_QUEUE_NAME your_dev_queue_name
                -DEPTH_THRESHOLD 100
                -GROWTH_RATE_THRESHOLD_PERCENT 50
                -GROWTH_CHECK_INTERVAL_SECONDS 300
                -SCALER_FUNCTION_URL $(DEV_SCALER_FUNCTION_URL)
                -SCALER_FUNCTION_KEY $(DevScalerFunctionKey) # From Variable Group (secret)
                -STATE_STORAGE_ACCOUNT_NAME your_dev_checkfunc_storage_name
                -STATE_TABLE_NAME queuestatestore
                -AZURE_SUBSCRIPTION_ID $(SubscriptionId) # From Variable Group
                -WEBSITE_RUN_FROM_PACKAGE 1 # Recommended for reliability

          - task: AzureFunctionApp@2
            displayName: 'Deploy IncreaseHpaAksFunction to Dev'
            inputs:
              azureSubscription: 'YourAzureServiceConnectionName'
              appType: 'functionAppLinux'
              appName: $(DEV_SCALE_FUNC_APP_NAME)
              package: '$(System.ArtifactsDirectory)/functionapps/IncreaseHpaAksFunction.zip'
              runtimeStack: 'DOTNET-ISOLATED|9.0'
              deploymentMethod: 'auto'
              appSettings: >-
                -AKS_RESOURCE_GROUP rg-cds-optmz-dev
                -AKS_CLUSTER_NAME cdsaksclusterdev
                -TARGET_HPA_NAME your_dev_hpa_name
                -TARGET_HPA_NAMESPACE your_dev_hpa_namespace
                -INCREASE_MAX_BY_COUNT 2
                -ABSOLUTE_MAX_REPLICAS 10 # Dev specific cap
                -AZURE_SUBSCRIPTION_ID $(SubscriptionId)
                -WEBSITE_RUN_FROM_PACKAGE 1

- stage: DeployProd
  displayName: 'Deploy to Prod Environment'
  dependsOn: Build
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: DeployFunctionsProd
    displayName: 'Deploy Functions to Prod'
    environment: 'YourProdEnvironmentNameInAzureDevOps' # Requires approval if configured
    pool:
      vmImage: 'windows-latest'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: DownloadBuildArtifacts@1
            displayName: 'Download Artifacts'
            inputs:
              buildType: 'current'
              downloadType: 'single'
              artifactName: 'functionapps'
              downloadPath: '$(System.ArtifactsDirectory)'

          - task: AzureFunctionApp@2
            displayName: 'Deploy CheckSaQueueFunction to Prod'
            inputs:
              azureSubscription: 'YourAzureServiceConnectionName'
              appType: 'functionAppLinux'
              appName: $(PROD_CHECK_FUNC_APP_NAME)
              package: '$(System.ArtifactsDirectory)/functionapps/CheckSaQueueFunction.zip'
              runtimeStack: 'DOTNET-ISOLATED|9.0'
              deploymentMethod: 'auto'
              appSettings: >- # Prod specific settings
                -MONITORED_STORAGE_ACCOUNT_NAME your_prod_storage_account_name
                -MONITORED_QUEUE_NAME your_prod_queue_name
                -DEPTH_THRESHOLD 200
                -GROWTH_RATE_THRESHOLD_PERCENT 30
                -GROWTH_CHECK_INTERVAL_SECONDS 180
                -SCALER_FUNCTION_URL $(PROD_SCALER_FUNCTION_URL)
                -SCALER_FUNCTION_KEY $(ProdScalerFunctionKey)
                -STATE_STORAGE_ACCOUNT_NAME your_prod_checkfunc_storage_name
                -STATE_TABLE_NAME queuestatestore
                -AZURE_SUBSCRIPTION_ID $(SubscriptionId)
                -WEBSITE_RUN_FROM_PACKAGE 1

          - task: AzureFunctionApp@2
            displayName: 'Deploy IncreaseHpaAksFunction to Prod'
            inputs:
              azureSubscription: 'YourAzureServiceConnectionName'
              appType: 'functionAppLinux'
              appName: $(PROD_SCALE_FUNC_APP_NAME)
              package: '$(System.ArtifactsDirectory)/functionapps/IncreaseHpaAksFunction.zip'
              runtimeStack: 'DOTNET-ISOLATED|9.0'
              deploymentMethod: 'auto'
              appSettings: >- # Prod specific settings
                -AKS_RESOURCE_GROUP your_prod_aks_rg # e.g., rg-cds-optmz-prod
                -AKS_CLUSTER_NAME your_prod_aks_cluster # e.g., cdsaksclusterprod
                -TARGET_HPA_NAME your_prod_hpa_name
                -TARGET_HPA_NAMESPACE your_prod_hpa_namespace
                -INCREASE_MAX_BY_COUNT 5
                -ABSOLUTE_MAX_REPLICAS 50 # Prod specific cap
                -AZURE_SUBSCRIPTION_ID $(SubscriptionId)
                -WEBSITE_RUN_FROM_PACKAGE 1
```

**Azure DevOps Setup for Pipeline:**

1.  **Service Connection:** Create an Azure Resource Manager service connection in Azure DevOps Project Settings -> Service connections. Grant it "Contributor" role on the resource groups containing your Function Apps (or on the Function Apps themselves).
2.  **Environments:** In Azure DevOps Pipelines -> Environments, create environments like `YourDevEnvironmentNameInAzureDevOps` and `YourProdEnvironmentNameInAzureDevOps`. You can add approvals for the prod environment.
3.  **Variable Groups:** Create Variable Groups (Pipelines -> Library) to store secrets like `DevScalerFunctionKey`, `ProdScalerFunctionKey`, `SubscriptionId`, and other environment-specific settings that you don't want directly in YAML. Link these to your pipeline or stages.
4.  **Function App Names:** Ensure the `DEV_CHECK_FUNC_APP_NAME`, `PROD_CHECK_FUNC_APP_NAME`, etc., variables match your actual Azure Function App names.
5.  **Runtime Stack:** The `runtimeStack: 'DOTNET-ISOLATED|9.0'` string for `AzureFunctionApp@2` task might need adjustment based on how Azure lists .NET 9 isolated support. Check the task documentation or Azure portal for the correct string if deployment fails due to runtime.

---

**Step 5: Local Development and Testing**

1.  Populate `local.settings.json` in each function project with appropriate values.
    *   For Managed Identity locally, you can authenticate via Azure CLI (`az login`), Visual Studio Azure Service Authentication, or by setting `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_CLIENT_SECRET` (for a Service Principal with permissions, if you're not using your user identity). `DefaultAzureCredential` will try various methods.
2.  Run locally: `func start` in each function's project directory (in separate terminals).
3.  Test the `check_sa_queue` by waiting for the timer or triggering it manually via the Functions admin endpoint.
4.  Test `increase_hpa_aks` using Postman or `curl` to its local HTTP endpoint.

---

**Step 6: Deployment and Azure Configuration**

1.  Commit and push your code to your Azure DevOps Git repository. The pipeline should trigger.
2.  After deployment, verify all Application Settings are correctly set in the Azure Portal for each Function App, especially for different environments.
    *   `checksaqueuefuncapp-dev` / `checksaqueuefuncapp-prod`
    *   `increasehpafuncapp-dev` / `increasehpafuncapp-prod`
    *   Ensure the `SCALER_FUNCTION_URL` in `checksaqueuefuncapp-*` points to the correct `increasehpafuncapp-*` URL for that environment.
    *   Ensure the `SCALER_FUNCTION_KEY` is correctly set if you're using function-level authorization.

