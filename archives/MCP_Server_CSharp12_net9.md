 #### Azure Function v4 using C# 12 and .NET 9 
 
This "MCP Server" will act as an API layer that LLM clients can call to manage Azure Kubernetes Service (AKS) resources.

**Core Concepts:**

1.  **MCP Server (as an Azure Function):**
    *   It will expose HTTP endpoints.
    *   It will receive structured requests (JSON) from LLM clients. These requests will specify the desired action (e.g., "list_aks_clusters", "scale_nodepool") and parameters (subscription ID, resource group, cluster name, node count, etc.).
    *   It will use the Azure SDK for .NET to interact with Azure Resource Manager (ARM).
    *   It will authenticate to Azure using a Managed Identity for secure, credential-less access.

2.  **LLM Client Interaction (Conceptual):**
    *   The LLM client (e.g., a chatbot, an autonomous agent) would be programmed or prompted to understand user intent related to Azure management.
    *   When a user says "List all Kubernetes clusters in subscription X" or "Scale the 'default' node pool in 'my-aks-cluster' in 'my-rg' to 5 nodes", the LLM would:
        *   Parse the intent and extract entities (action, subscription, resource group, cluster name, etc.).
        *   Format a JSON request for our MCP Server.
        *   Call the MCP Server's HTTP endpoint.
        *   Receive the JSON response and present it to the user or take further action.

3.  **Azure Resource Management:**
    *   We'll use the `Azure.ResourceManager` family of NuGet packages, which provide a modern, object-oriented way to interact with Azure resources.
    *   Specifically, `Azure.ResourceManager.ContainerService` for AKS.

4.  **Security:**
    *   **Function to Azure:** Managed Identity (System-Assigned or User-Assigned). This identity will need appropriate RBAC roles (e.g., "Azure Kubernetes Service Contributor Role" or a custom role with finer-grained permissions) on the target subscriptions or resource groups.
    *   **Client to Function:** Azure Function authentication/authorization (e.g., Function Keys, API Keys via API Management, or Azure AD). For simplicity, we'll start with Function Keys.

**Prerequisites:**

*   .NET SDK (latest stable, e.g., .NET 8. We'll use C# 12 features. .NET 9 support in Azure Functions is upcoming).
*   Azure Functions Core Tools v4.
*   Azure CLI or PowerShell with Azure modules.
*   An Azure Subscription.
*   Visual Studio Code or Visual Studio 2022.

---

**Step-by-Step Implementation:**

**Step 1: Create the Azure Function Project**

1.  Open your terminal or command prompt.
2.  Create a new directory for your project and navigate into it:
    ```bash
    mkdir McpAzureManager
    cd McpAzureManager
    ```
3.  Create a new Azure Function project (using the isolated worker model, which is best for .NET 8+):
    ```bash
    func init .  --framework net9.0
    # For .NET 9 when officially supported by Functions:
    # func init . --worker-runtime dotnet-isolated --target-framework net9.0
    git init # Optional: Initialize a git repository
    ```
4.  Create an HTTP-triggered function:
    ```bash
    func new --name AksManagerFunction --template "Http trigger" --authlevel "function"
    ```
    ```
    dotnet new func -n AksManagerFunction  --framework net9.0
    ```
    This creates a function that requires a function key for access.

**Step 2: Add Necessary NuGet Packages**

Edit your `.csproj` file (`McpAzureManager.csproj`) and add the following packages:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <!-- <TargetFramework>net9.0</TargetFramework> -->
    <AzureFunctionsVersion>v4</AzureFunctionsVersion>
    <OutputType>Exe</OutputType>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <LangVersion>12.0</LangVersion>
  </PropertyGroup>
  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" /> <!-- For HttpContext and JSON support -->
    <PackageReference Include="Azure.Identity" Version="1.12.0" />
    <PackageReference Include="Azure.ResourceManager" Version="1.12.0" />
    <PackageReference Include="Azure.ResourceManager.ContainerService" Version="1.2.1" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.22.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.2.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.2" />
    <PackageReference Include="Microsoft.ApplicationInsights.WorkerService" Version="2.22.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="1.2.0" />
    <PackageReference Include="System.Text.Json" Version="8.0.4" />
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
    <Using Include="System.Threading.ExecutionContext" Alias="ExecutionContext" />
  </ItemGroup>
</Project>
```
*Run `dotnet restore` after saving.*

**Step 3: Define Request and Response Models**

Create a new folder `Models` and add the following files:

*   `Models/McpRequest.cs`:
    ```csharp
    using System.Text.Json.Serialization;

    namespace McpAzureManager.Models;

    public class McpRequest
    {
        [JsonPropertyName("action")]
        public string? Action { get; set; }

        [JsonPropertyName("subscriptionId")]
        public string? SubscriptionId { get; set; } // Required for most actions

        [JsonPropertyName("resourceGroupName")]
        public string? ResourceGroupName { get; set; } // Optional or required based on action

        [JsonPropertyName("clusterName")]
        public string? ClusterName { get; set; } // Optional or required based on action

        [JsonPropertyName("agentPoolName")]
        public string? AgentPoolName { get; set; } // For agent pool specific actions

        [JsonPropertyName("nodeCount")]
        public int? NodeCount { get; set; } // For scaling

        // Add other parameters as needed
        [JsonPropertyName("parameters")]
        public Dictionary<string, string>? AdditionalParameters { get; set; }
    }

    // Enum for better action handling (optional but recommended)
    public enum AksAction
    {
        Unknown,
        ListClustersInSubscription,
        ListClustersInResourceGroup,
        GetClusterDetails,
        StartCluster, // Starting/Stopping entire cluster is via start/stop agent pools
        StopCluster,  // Or cluster start/stop preview feature
        ScaleNodePool,
        GetNodePoolDetails,
        ListNodePools,
        GetClusterAdminKubeConfig
        // Add more actions like CreateCluster, DeleteCluster, UpdateCluster etc.
    }
    ```

*   `Models/McpResponse.cs`:
    ```csharp
    using System.Text.Json.Serialization;

    namespace McpAzureManager.Models;

    public class McpResponse
    {
        [JsonPropertyName("status")]
        public string Status { get; set; } = "error"; // "success" or "error"

        [JsonPropertyName("message")]
        public string? Message { get; set; }

        [JsonPropertyName("data")]
        [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
        public object? Data { get; set; }

        public static McpResponse Success(object? data = null, string? message = null) =>
            new() { Status = "success", Data = data, Message = message ?? "Operation completed successfully." };

        public static McpResponse Error(string message, object? data = null) =>
            new() { Status = "error", Message = message, Data = data };
    }
    ```

**Step 4: Implement the AKS Management Service**

Create a new folder `Services` and add `AksManagementService.cs`:

```csharp
using Azure;
using Azure.Core;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.ContainerService;
using Azure.ResourceManager.Resources;
using McpAzureManager.Models;
using Microsoft.Extensions.Logging;

namespace McpAzureManager.Services;

public class AksManagementService(ArmClient armClient, ILogger<AksManagementService> logger)
{
    private readonly ArmClient _armClient = armClient;
    private readonly ILogger<AksManagementService> _logger = logger;

    private SubscriptionResource GetSubscription(string subscriptionId)
    {
        var subId = $"/subscriptions/{subscriptionId}";
        return _armClient.GetSubscriptionResource(new ResourceIdentifier(subId));
    }

    private async Task<ResourceGroupResource> GetResourceGroupAsync(string subscriptionId, string resourceGroupName)
    {
        var subscription = GetSubscription(subscriptionId);
        var rgResponse = await subscription.GetResourceGroupAsync(resourceGroupName);
        if (rgResponse == null || !rgResponse.HasValue)
        {
            throw new ArgumentException($"Resource group '{resourceGroupName}' not found in subscription '{subscriptionId}'.");
        }
        return rgResponse.Value;
    }

    private async Task<ContainerServiceResource> GetAksClusterAsync(string subscriptionId, string resourceGroupName, string clusterName)
    {
        var rg = await GetResourceGroupAsync(subscriptionId, resourceGroupName);
        var clusterResponse = await rg.GetContainerServiceAsync(clusterName);
        if (clusterResponse == null || !clusterResponse.HasValue)
        {
            throw new ArgumentException($"AKS cluster '{clusterName}' not found in '{resourceGroupName}/{subscriptionId}'.");
        }
        return clusterResponse.Value;
    }

    public async Task<object> ListClustersInSubscriptionAsync(string subscriptionId)
    {
        _logger.LogInformation("Listing AKS clusters in subscription {SubscriptionId}", subscriptionId);
        var subscription = GetSubscription(subscriptionId);
        var clusters = new List<object>();

        await foreach (var rg in subscription.GetResourceGroupsAsync())
        {
            await foreach (var cluster in rg.GetContainerServicesAsync())
            {
                clusters.Add(new
                {
                    cluster.Data.Name,
                    cluster.Data.Location,
                    ResourceGroupName = rg.Data.Name,
                    ProvisioningState = cluster.Data.ProvisioningState,
                    KubernetesVersion = cluster.Data.KubernetesVersion,
                    PowerState = cluster.Data.PowerState?.Code.ToString()
                });
            }
        }
        return clusters;
    }

    public async Task<object> ListClustersInResourceGroupAsync(string subscriptionId, string resourceGroupName)
    {
        _logger.LogInformation("Listing AKS clusters in RG {ResourceGroupName} of subscription {SubscriptionId}", resourceGroupName, subscriptionId);
        var rg = await GetResourceGroupAsync(subscriptionId, resourceGroupName);
        var clusters = new List<object>();
        await foreach (var cluster in rg.GetContainerServicesAsync())
        {
            clusters.Add(new
            {
                cluster.Data.Name,
                cluster.Data.Location,
                ResourceGroupName = rg.Data.Name,
                ProvisioningState = cluster.Data.ProvisioningState,
                KubernetesVersion = cluster.Data.KubernetesVersion,
                PowerState = cluster.Data.PowerState?.Code.ToString()
            });
        }
        return clusters;
    }

    public async Task<object> GetClusterDetailsAsync(string subscriptionId, string resourceGroupName, string clusterName)
    {
        _logger.LogInformation("Getting details for AKS cluster {ClusterName} in {ResourceGroupName}/{SubscriptionId}", clusterName, resourceGroupName, subscriptionId);
        var cluster = await GetAksClusterAsync(subscriptionId, resourceGroupName, clusterName);
        return new
        {
            cluster.Data.Name,
            Id = cluster.Data.Id.ToString(),
            cluster.Data.Location,
            ResourceGroupName = cluster.Data.ResourceGroupId.ResourceGroupName,
            ProvisioningState = cluster.Data.ProvisioningState,
            PowerState = cluster.Data.PowerState?.Code.ToString(),
            KubernetesVersion = cluster.Data.KubernetesVersion,
            Fqdn = cluster.Data.Fqdn,
            NodeResourceGroup = cluster.Data.NodeResourceGroup,
            AgentPoolProfiles = cluster.Data.AgentPoolProfiles.Select(p => new
            {
                p.Name,
                p.Count,
                p.VmSize,
                p.OSType,
                p.Mode,
                PowerState = p.PowerState?.Code.ToString(),
                ProvisioningState = p.ProvisioningState
            }).ToList()
        };
    }

    public async Task<object> ScaleNodePoolAsync(string subscriptionId, string resourceGroupName, string clusterName, string agentPoolName, int nodeCount)
    {
        _logger.LogInformation("Scaling agent pool {AgentPoolName} in cluster {ClusterName} to {NodeCount} nodes.", agentPoolName, clusterName, nodeCount);
        var cluster = await GetAksClusterAsync(subscriptionId, resourceGroupName, clusterName);
        var agentPool = await cluster.GetContainerServiceAgentPoolAsync(agentPoolName);

        if (agentPool == null || !agentPool.HasValue)
        {
            throw new ArgumentException($"Agent pool '{agentPoolName}' not found in cluster '{clusterName}'.");
        }

        var agentPoolData = agentPool.Value.Data;
        agentPoolData.Count = nodeCount;

        var operation = await agentPool.Value.UpdateAsync(WaitUntil.Started, agentPoolData);
        _logger.LogInformation("Scale operation started for agent pool {AgentPoolName}. Waiting for completion is not implemented in this PoC.", agentPoolName);
        // For production, you might want to wait or return an operation ID
        // await operation.WaitForCompletionAsync();
        return new
        {
            AgentPoolName = agentPoolName,
            RequestedNodeCount = nodeCount,
            Status = $"Scale operation initiated. Current state: {agentPool.Value.Data.ProvisioningState}. Check Azure portal for progress."
            // OperationId = operation.Id // If you want to track it
        };
    }

    public async Task<object> StartOrStopNodePoolAsync(string subscriptionId, string resourceGroupName, string clusterName, string agentPoolName, bool start)
    {
        var action = start ? "Starting" : "Stopping";
        _logger.LogInformation("{Action} agent pool {AgentPoolName} in cluster {ClusterName}", action, agentPoolName, clusterName);

        var cluster = await GetAksClusterAsync(subscriptionId, resourceGroupName, clusterName);
        var agentPool = await cluster.GetContainerServiceAgentPoolAsync(agentPoolName);
        if (!agentPool.HasValue)
        {
            throw new ArgumentException($"Agent pool '{agentPoolName}' not found in cluster '{clusterName}'.");
        }

        // Starting/Stopping node pools directly is not available through a simple property.
        // It's usually done by setting powerState, but the SDK might not expose it directly for update.
        // For stopping, scaling to 0 is the common workaround if the pool allows. For starting, scale > 0.
        // AKS Start/Stop cluster feature applies to the whole cluster (all node pools)
        // Check if the agent pool can be scaled to 0. Some system node pools might not allow this.
        if (!start && agentPool.Value.Data.Mode == ContainerServiceAgentPoolMode.System && agentPool.Value.Data.Count <=1) {
             _logger.LogWarning("Cannot stop system node pool {AgentPoolName} by scaling to 0 if it's the last system node.", agentPoolName);
             throw new InvalidOperationException($"Cannot stop system node pool {agentPoolName} by scaling to 0 if it's the last system node or critical.");
        }
        
        var agentPoolData = agentPool.Value.Data;
        if(start)
        {
            // To "start" a stopped (scaled to 0) pool, scale it to its previous count or a default.
            // This example scales to 1 or its original count if known and non-zero.
            // A more robust solution would store the previous count before stopping.
            if (agentPoolData.Count == 0) agentPoolData.Count = 1; // Or retrieve a stored 'last known count'
            // If it was stopped using cluster stop, this won't work; need cluster start.
        }
        else // Stop
        {
            agentPoolData.Count = 0;
        }
        
        // The actual start/stop feature for cluster level is managed differently
        // Let's focus on scaling to 0 for "stop" and >0 for "start" for a specific node pool
        _logger.LogInformation("Attempting to {Action} node pool {AgentPoolName} by setting count to {Count}", action, agentPoolName, agentPoolData.Count);
        var operation = await agentPool.Value.UpdateAsync(WaitUntil.Started, agentPoolData);

        return new
        {
            AgentPoolName = agentPoolName,
            Action = action,
            RequestedNodeCount = agentPoolData.Count,
            Status = $"{action} operation initiated. Current state: {agentPool.Value.Data.ProvisioningState}. Check Azure portal for progress."
        };
    }


    public async Task<object> StartOrStopEntireClusterAsync(string subscriptionId, string resourceGroupName, string clusterName, bool start)
    {
        // This uses the cluster-level start/stop feature (Preview as of writing, but generally available)
        var action = start ? "Starting" : "Stopping";
        _logger.LogInformation("{Action} entire cluster {ClusterName} in {ResourceGroupName}/{SubscriptionId}", action, clusterName, resourceGroupName, subscriptionId);
        var cluster = await GetAksClusterAsync(subscriptionId, resourceGroupName, clusterName);

        ArmOperation operation;
        if (start)
        {
            operation = await cluster.StartAsync(WaitUntil.Started);
        }
        else
        {
            operation = await cluster.StopAsync(WaitUntil.Started);
        }
        _logger.LogInformation("{Action} operation for cluster {ClusterName} initiated.", action, clusterName);
        // await operation.WaitForCompletionResponseAsync(); // If you need to wait

        return new
        {
            ClusterName = clusterName,
            Action = action,
            Status = $"{action} operation initiated. Check Azure portal for progress."
        };
    }


    public async Task<object> ListNodePoolsAsync(string subscriptionId, string resourceGroupName, string clusterName)
    {
        _logger.LogInformation("Listing node pools for AKS cluster {ClusterName} in {ResourceGroupName}/{SubscriptionId}", clusterName, resourceGroupName, subscriptionId);
        var cluster = await GetAksClusterAsync(subscriptionId, resourceGroupName, clusterName);
        var nodePools = new List<object>();

        await foreach (var pool in cluster.GetContainerServiceAgentPools().GetAllAsync())
        {
            nodePools.Add(new
            {
                pool.Data.Name,
                pool.Data.Count,
                pool.Data.VmSize,
                pool.Data.OSType,
                pool.Data.Mode,
                pool.Data.ProvisioningState,
                PowerState = pool.Data.PowerState?.Code.ToString()
            });
        }
        return nodePools;
    }

     public async Task<object> GetClusterAdminKubeConfigAsync(string subscriptionId, string resourceGroupName, string clusterName)
    {
        _logger.LogInformation("Getting admin KubeConfig for AKS cluster {ClusterName}", clusterName);
        var cluster = await GetAksClusterAsync(subscriptionId, resourceGroupName, clusterName);
        
        // This gets the admin credentials
        var credentialResults = await cluster.GetAdminCredentialsAsync();
        var kubeConfig = string.Empty;

        foreach(var result in credentialResults.Value.Kubeconfigs)
        {
            if (result.Name.Equals("clusterAdmin", StringComparison.OrdinalIgnoreCase))
            {
                kubeConfig = System.Text.Encoding.UTF8.GetString(result.Value);
                break;
            }
        }

        if (string.IsNullOrEmpty(kubeConfig))
        {
            throw new InvalidOperationException("Admin KubeConfig not found.");
        }

        return new { KubeConfig = kubeConfig }; // Be careful with returning sensitive data directly
    }
}
```

**Step 5: Modify the Azure Function (`AksManagerFunction.cs`)**

Replace the content of `AksManagerFunction.cs` with the following:

```csharp
using System.Net;
using System.Text.Json;
using McpAzureManager.Models;
using McpAzureManager.Services;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace McpAzureManager;

public class AksManagerFunction(ILogger<AksManagerFunction> logger, AksManagementService aksService, JsonSerializerOptions jsonOptions)
{
    private readonly ILogger<AksManagerFunction> _logger = logger;
    private readonly AksManagementService _aksService = aksService;
    private readonly JsonSerializerOptions _jsonOptions = jsonOptions;

    [Function("AksManagerFunction")]
    public async Task<HttpResponseData> RunAsync(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "aks/{action?}")] HttpRequestData req,
        string? action) // Optional route parameter for action
    {
        _logger.LogInformation("C# HTTP trigger function processed a request for action: {Action}", action);

        McpRequest? mcpRequest = null;
        AksAction parsedAction = AksAction.Unknown;

        try
        {
            var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            if (string.IsNullOrEmpty(requestBody) && !string.IsNullOrEmpty(action))
            {
                 // If body is empty but action is in route, create a minimal request
                 mcpRequest = new McpRequest { Action = action };
            }
            else if (!string.IsNullOrEmpty(requestBody))
            {
                mcpRequest = JsonSerializer.Deserialize<McpRequest>(requestBody, _jsonOptions);
                if (mcpRequest != null && string.IsNullOrEmpty(mcpRequest.Action) && !string.IsNullOrEmpty(action))
                {
                    mcpRequest.Action = action; // Prefer action from route if body doesn't specify
                }
            }
            
            if (mcpRequest == null || string.IsNullOrWhiteSpace(mcpRequest.Action))
            {
                return await CreateJsonResponse(req, HttpStatusCode.BadRequest, McpResponse.Error("Action not specified in request body or route."));
            }

            // Simple parsing of action string to enum
            if (!Enum.TryParse<AksAction>(mcpRequest.Action, true, out parsedAction))
            {
                 return await CreateJsonResponse(req, HttpStatusCode.BadRequest, McpResponse.Error($"Invalid action: {mcpRequest.Action}"));
            }

            // Validate required parameters
            if (string.IsNullOrWhiteSpace(mcpRequest.SubscriptionId) &&
                parsedAction != AksAction.Unknown) // Add other actions that might not need SubId
            {
                return await CreateJsonResponse(req, HttpStatusCode.BadRequest, McpResponse.Error("SubscriptionId is required."));
            }

            object result;
            switch (parsedAction)
            {
                case AksAction.ListClustersInSubscription:
                    ValidateNotNull(mcpRequest.SubscriptionId, nameof(mcpRequest.SubscriptionId));
                    result = await _aksService.ListClustersInSubscriptionAsync(mcpRequest.SubscriptionId!);
                    break;

                case AksAction.ListClustersInResourceGroup:
                    ValidateNotNull(mcpRequest.SubscriptionId, nameof(mcpRequest.SubscriptionId));
                    ValidateNotNull(mcpRequest.ResourceGroupName, nameof(mcpRequest.ResourceGroupName));
                    result = await _aksService.ListClustersInResourceGroupAsync(mcpRequest.SubscriptionId!, mcpRequest.ResourceGroupName!);
                    break;

                case AksAction.GetClusterDetails:
                    ValidateNotNull(mcpRequest.SubscriptionId, nameof(mcpRequest.SubscriptionId));
                    ValidateNotNull(mcpRequest.ResourceGroupName, nameof(mcpRequest.ResourceGroupName));
                    ValidateNotNull(mcpRequest.ClusterName, nameof(mcpRequest.ClusterName));
                    result = await _aksService.GetClusterDetailsAsync(mcpRequest.SubscriptionId!, mcpRequest.ResourceGroupName!, mcpRequest.ClusterName!);
                    break;
                
                case AksAction.ListNodePools:
                    ValidateNotNull(mcpRequest.SubscriptionId, nameof(mcpRequest.SubscriptionId));
                    ValidateNotNull(mcpRequest.ResourceGroupName, nameof(mcpRequest.ResourceGroupName));
                    ValidateNotNull(mcpRequest.ClusterName, nameof(mcpRequest.ClusterName));
                    result = await _aksService.ListNodePoolsAsync(mcpRequest.SubscriptionId!, mcpRequest.ResourceGroupName!, mcpRequest.ClusterName!);
                    break;

                case AksAction.ScaleNodePool:
                    ValidateNotNull(mcpRequest.SubscriptionId, nameof(mcpRequest.SubscriptionId));
                    ValidateNotNull(mcpRequest.ResourceGroupName, nameof(mcpRequest.ResourceGroupName));
                    ValidateNotNull(mcpRequest.ClusterName, nameof(mcpRequest.ClusterName));
                    ValidateNotNull(mcpRequest.AgentPoolName, nameof(mcpRequest.AgentPoolName));
                    if (mcpRequest.NodeCount == null || mcpRequest.NodeCount < 0) 
                        throw new ArgumentException("Valid NodeCount is required for scaling.");
                    result = await _aksService.ScaleNodePoolAsync(mcpRequest.SubscriptionId!, mcpRequest.ResourceGroupName!, mcpRequest.ClusterName!, mcpRequest.AgentPoolName!, mcpRequest.NodeCount.Value);
                    break;

                case AksAction.StartCluster: // Entire cluster start
                    ValidateNotNull(mcpRequest.SubscriptionId, nameof(mcpRequest.SubscriptionId));
                    ValidateNotNull(mcpRequest.ResourceGroupName, nameof(mcpRequest.ResourceGroupName));
                    ValidateNotNull(mcpRequest.ClusterName, nameof(mcpRequest.ClusterName));
                    result = await _aksService.StartOrStopEntireClusterAsync(mcpRequest.SubscriptionId!, mcpRequest.ResourceGroupName!, mcpRequest.ClusterName!, true);
                    break;

                case AksAction.StopCluster: // Entire cluster stop
                    ValidateNotNull(mcpRequest.SubscriptionId, nameof(mcpRequest.SubscriptionId));
                    ValidateNotNull(mcpRequest.ResourceGroupName, nameof(mcpRequest.ResourceGroupName));
                    ValidateNotNull(mcpRequest.ClusterName, nameof(mcpRequest.ClusterName));
                    result = await _aksService.StartOrStopEntireClusterAsync(mcpRequest.SubscriptionId!, mcpRequest.ResourceGroupName!, mcpRequest.ClusterName!, false);
                    break;

                case AksAction.GetClusterAdminKubeConfig:
                    ValidateNotNull(mcpRequest.SubscriptionId, nameof(mcpRequest.SubscriptionId));
                    ValidateNotNull(mcpRequest.ResourceGroupName, nameof(mcpRequest.ResourceGroupName));
                    ValidateNotNull(mcpRequest.ClusterName, nameof(mcpRequest.ClusterName));
                    result = await _aksService.GetClusterAdminKubeConfigAsync(mcpRequest.SubscriptionId!, mcpRequest.ResourceGroupName!, mcpRequest.ClusterName!);
                    break;

                default:
                    return await CreateJsonResponse(req, HttpStatusCode.BadRequest, McpResponse.Error($"Action '{mcpRequest.Action}' is not supported."));
            }
            return await CreateJsonResponse(req, HttpStatusCode.OK, McpResponse.Success(result));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning(ex, "Invalid argument for action {Action}: {ErrorMessage}", parsedAction, ex.Message);
            return await CreateJsonResponse(req, HttpStatusCode.BadRequest, McpResponse.Error(ex.Message));
        }
        catch (RequestFailedException ex) // Azure SDK specific exception
        {
            _logger.LogError(ex, "Azure API request failed for action {Action}: {StatusCode} - {ErrorMessage}", parsedAction, ex.Status, ex.Message);
            return await CreateJsonResponse(req, (HttpStatusCode)ex.Status, McpResponse.Error($"Azure API error: {ex.Message}", new { ErrorCode = ex.ErrorCode }));
        }
        catch (JsonException ex)
        {
            _logger.LogWarning(ex, "Failed to parse request body for action {Action}: {ErrorMessage}", parsedAction, ex.Message);
            return await CreateJsonResponse(req, HttpStatusCode.BadRequest, McpResponse.Error($"Invalid JSON request: {ex.Message}"));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An unexpected error occurred while processing action {Action}", parsedAction);
            return await CreateJsonResponse(req, HttpStatusCode.InternalServerError, McpResponse.Error($"An internal error occurred: {ex.Message}"));
        }
    }

    private void ValidateNotNull(string? value, string paramName)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new ArgumentException($"{paramName} cannot be null or empty.");
        }
    }
    
    private async Task<HttpResponseData> CreateJsonResponse(HttpRequestData req, HttpStatusCode statusCode, object payload)
    {
        var response = req.CreateResponse(statusCode);
        await response.WriteAsJsonAsync(payload, _jsonOptions); // Using WriteAsJsonAsync for proper content type
        return response;
    }
}
```

**Step 6: Configure Dependency Injection (`Program.cs`)**

Modify `Program.cs` for dependency injection:

```csharp
using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.Identity;
using Azure.ResourceManager;
using McpAzureManager.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication() // Correct method for .NET Isolated
    .ConfigureServices(services =>
    {
        // Configure logging
        services.AddLogging(loggingBuilder =>
        {
            loggingBuilder.AddConsole(); // Add other providers as needed
        });

        // Register ArmClient with DefaultAzureCredential
        // DefaultAzureCredential will use Managed Identity when deployed to Azure,
        // and local development credentials (Azure CLI, VS, Env Vars) when running locally.
        services.AddSingleton(provider =>
        {
            var credential = new DefaultAzureCredential();
            // You can specify options for DefaultAzureCredential if needed, e.g., ManagedIdentityClientId
            // var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
            // {
            //    ManagedIdentityClientId = Environment.GetEnvironmentVariable("MANAGED_IDENTITY_CLIENT_ID") 
            //    // This is useful if using User-Assigned Managed Identity
            // });
            return new ArmClient(credential);
        });

        // Register our custom service
        services.AddScoped<AksManagementService>();

        // Configure JsonSerializerOptions
        services.AddSingleton(provider =>
        {
            var options = new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
                PropertyNameCaseInsensitive = true // For deserialization flexibility
            };
            options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase)); // Enum as string
            return options;
        });
    })
    .Build();

host.Run();
```

**Step 7: Configure Local Settings (`local.settings.json`)**

For local development, `DefaultAzureCredential` will try various methods (Visual Studio, Azure CLI, Environment Variables). Ensure you are logged in via Azure CLI (`az login`) or Visual Studio with an account that has permissions on your test subscription(s).

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true", // Or your Azure Storage account connection string
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    // For DefaultAzureCredential local development, you might need these if not using CLI/VS login:
    // "AZURE_CLIENT_ID": "your-service-principal-client-id",
    // "AZURE_TENANT_ID": "your-tenant-id",
    // "AZURE_CLIENT_SECRET": "your-service-principal-client-secret",
    // If using a specific User-Assigned Managed Identity locally (less common for local dev, more for Azure deployment):
    // "MANAGED_IDENTITY_CLIENT_ID": "your-user-assigned-managed-identity-client-id"
  },
  "Host": { // Optional: Add for better local debugging of JSON
    "LocalHttpPort": 7071,
    "CORS": "*" // Be careful with CORS in production
  }
}
```

**Step 8: Test Locally**

1.  Start the function:
    ```bash
    func start
    ```
2.  The output will give you a URL, likely: `http://localhost:7071/api/aks/{action}`. You'll also need a function key. You can get a default host key or create a new function key.
    *   To get a default master key (for local testing ease):
        ```bash
        func azure functionapp fetch-app-settings <YourFunctionAppNameIfDeployed>
        # OR, if not deployed yet, one is usually generated.
        # Check console output or you can find/create keys in Azure Portal after deployment.
        # For local: a default master key is usually usable without explicit fetching.
        # If you have `AzureWebJobsStorage` set, keys are stored there.
        # If it's `UseDevelopmentStorage=true`, they are in Azure Storage Emulator or Azurite.
        # Easiest: after first run, a file `azurefunctions-secrets/AksManagerFunction.Function. primul` might appear, or use master key.
        # Let's assume you find the master key or function key.
        # A master key is generally available at `_master` in the secrets file or `admin/host/keys/default` endpoint.
        # Example: "x-functions-key: YOUR_MASTER_KEY_OR_FUNCTION_KEY"
        ```
    *   Alternatively, change `AuthorizationLevel.Function` to `AuthorizationLevel.Anonymous` in `AksManagerFunction.cs` *temporarily* for easy local testing without keys. **Remember to change it back for production.**

3.  Use Postman, curl, or a simple client to send POST requests:

    *   **URL:** `http://localhost:7071/api/aks/ListClustersInSubscription` (if using route parameter for action)
        OR `http://localhost:7071/api/aks` (and action in body)
    *   **Method:** `POST`
    *   **Headers:** `Content-Type: application/json`
        (If authlevel is `function`): `x-functions-key: YOUR_FUNCTION_KEY`
    *   **Body (Example: ListClustersInSubscription):**
        ```json
        {
            "action": "ListClustersInSubscription",
            "subscriptionId": "YOUR_AZURE_SUBSCRIPTION_ID"
        }
        ```
    *   **Body (Example: ScaleNodePool):**
        ```json
        {
            "action": "ScaleNodePool",
            "subscriptionId": "YOUR_AZURE_SUBSCRIPTION_ID",
            "resourceGroupName": "YOUR_RESOURCE_GROUP_NAME",
            "clusterName": "YOUR_AKS_CLUSTER_NAME",
            "agentPoolName": "nodepool1",
            "nodeCount": 3
        }
        ```
    *   **Body (Example: Get Admin KubeConfig):**
        ```json
        {
            "action": "GetClusterAdminKubeConfig",
            "subscriptionId": "YOUR_AZURE_SUBSCRIPTION_ID",
            "resourceGroupName": "YOUR_RESOURCE_GROUP_NAME",
            "clusterName": "YOUR_AKS_CLUSTER_NAME"
        }
        ```
        *(Warning: Returning raw KubeConfig can be a security risk. Consider alternatives for production if LLM clients are not fully trusted, e.g., returning a secure token to fetch it, or performing kubectl operations server-side.)*

**Step 9: Deploy to Azure**

1.  **Create Azure Function App:**
    *   Go to Azure Portal or use Azure CLI.
    *   Choose:
        *   Runtime stack: .NET
        *   Version: .NET 8 (Isolated Worker Process) (or .NET 9 when available and you've targeted it)
        *   Operating System: Windows or Linux
        *   Hosting Plan: Consumption (Serverless), Premium, or App Service Plan.
        *   Enable System-Assigned Managed Identity (under Settings -> Identity). Note its Object (principal) ID.

2.  **Assign RBAC Permissions to Managed Identity:**
    *   Navigate to your Subscription(s) or specific Resource Group(s) that this function will manage.
    *   Go to "Access control (IAM)".
    *   Click "Add" -> "Add role assignment".
    *   Role: "Azure Kubernetes Service Contributor Role" (provides broad AKS management capabilities). For more fine-grained control, create a custom role with only the necessary permissions (e.g., `Microsoft.ContainerService/managedClusters/read`, `Microsoft.ContainerService/managedClusters/agentPools/write`, `Microsoft.ContainerService/managedClusters/start/action`, `Microsoft.ContainerService/managedClusters/stop/action`, `Microsoft.ContainerService/managedClusters/listClusterAdminCredential/action`).
    *   Assign access to: "Managed identity".
    *   Select: The System-Assigned Managed Identity of your Function App.

3.  **Deploy the Function Code:**
    *   Using Azure Functions Core Tools:
        ```bash
        # Login if needed
        az login
        az account set --subscription "YOUR_SUBSCRIPTION_NAME_OR_ID"

        # Deploy
        func azure functionapp publish <YourFunctionAppName>
        ```
    *   Or use Visual Studio's "Publish" feature, or set up a CI/CD pipeline (GitHub Actions, Azure DevOps).

4.  **Configure Application Settings in Azure:**
    *   `AzureWebJobsStorage`: Must be set to a valid Azure Storage account connection string (usually configured during Function App creation).
    *   `FUNCTIONS_WORKER_RUNTIME`: Should be `dotnet-isolated`.
    *   If you used a User-Assigned Managed Identity, you'd add `MANAGED_IDENTITY_CLIENT_ID` with its Client ID. For System-Assigned, this isn't strictly needed for `DefaultAzureCredential` but can be explicit.

**Step 10: LLM Client Integration**

The LLM client needs to be configured to:
1.  Understand user intent for AKS management.
2.  Extract necessary parameters (subscription ID, RG, cluster name, etc.).
3.  Construct a JSON payload matching `McpRequest.cs`.
4.  Make an HTTP POST request to your deployed Azure Function URL (e.g., `https://<your-function-app-name>.azurewebsites.net/api/aks/{action}`).
5.  Include the Function Key in the `x-functions-key` header.
6.  Process the `McpResponse.cs` JSON response.

---

**Best Practices & Further Considerations:**

*   **.NET 9:** When Azure Functions officially supports .NET 9, you can change the `<TargetFramework>` in the `.csproj` and update NuGet packages if needed. C# 12 features are already usable with .NET 8.
*   **Error Handling & Logging:** The provided code includes basic error handling and logging. Expand this for production scenarios. Use Application Insights for robust monitoring.
*   **Input Validation:** The example has basic validation. Use a library like FluentValidation for more complex rules.
*   **Asynchronous Operations:** For long-running operations like creating/deleting clusters or complex updates, the current synchronous model will time out. You'd need to implement a Durable Functions pattern or a request-response pattern with polling:
    1.  Initial request starts the operation.
    2.  Function returns an `Operation-Location` header or a unique ID.
    3.  Client polls a status endpoint using this ID until completion.
*   **Idempotency:** Design write operations to be idempotent if possible.
*   **Security:**
    *   **Function Keys:** Simple, but shareable. Consider rotating them.
    *   **Azure AD Authentication:** For more robust security between client and Function, protect the Function App with Azure AD. The LLM client would then need to acquire an AAD token. This is more complex but standard for enterprise scenarios.
    *   **API Management:** Place Azure API Management in front of your Function App for policies like rate limiting, advanced authentication, request transformation, and a stable API facade.
    *   **Least Privilege:** Always assign the minimum necessary RBAC permissions to the Managed Identity.
*   **Configuration:** For multiple subscriptions, instead of hardcoding or passing them every time, you could have a configuration source (e.g., Azure App Configuration, Cosmos DB) that the MCP server reads to know which subscriptions it's allowed to manage or has default context for. However, passing `subscriptionId` in the request is explicit and flexible.
*   **Scalability:** Azure Functions (especially on Consumption plan) scale automatically. Ensure your Azure SDK usage is efficient (e.g., client reuse).
*   **Cost:** Be mindful of the operations. Listing resources across many subscriptions/RGs frequently can incur API call costs and take time.
*   **Multi-Subscription Strategy:**
    *   The current design requires the `subscriptionId` in each request. This is good for explicit control.
    *   The Managed Identity of the Function App needs RBAC access to *all* subscriptions it's intended to manage.
    *   If you want the MCP server to *discover* subscriptions the LLM client doesn't know about, the Managed Identity would need `Reader` access at a Management Group level, and the function could list subscriptions. This adds complexity.

This comprehensive guide should give you a solid foundation for your C# 12 MCP Server on Azure Functions for managing Azure resources. 