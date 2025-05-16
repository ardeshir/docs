#### Azure Function SA, JSAON

##### Step-by-step:

Focusing on `DefaultAzureCredential` for Azure Storage access and calling another function.

**Assumptions:**

*   You have Azure CLI installed and configured (`az login`).
*   You have .NET 9 SDK installed.
*   You have an Azure Subscription where you can create resources.
*   The "target" Azure Function (the one being called) already exists or you know its URL and function key. If it doesn't exist, you'll need to create a simple HTTP trigger function for testing.

---

**Phase 1: Project Setup and Code Implementation**

1.  **Create New Azure Function Project (Isolated Worker, .NET 9):**
    ```bash
    dotnet new func --isolated-worker --target-framework net9.0 -o StorageToJsonRelayFunction
    cd StorageToJsonRelayFunction
    ```
    ```
    func init StorageJsonRelayFunc --worker-runtime dotnet-isolated --language C#  
    ```

2.  **Add Necessary NuGet Packages:**
    ```bash
    dotnet add package Azure.Identity # For DefaultAzureCredential
    dotnet add package Azure.Storage.Blobs # For Azure Blob Storage
    dotnet add package Microsoft.Extensions.Http # For IHttpClientFactory
    dotnet add package Microsoft.Extensions.Azure # For simplified Azure SDK client registration (optional but good)
    # Microsoft.Extensions.Configuration.Json, Options.ConfigurationExtensions, DependencyInjection are usually included
    ```

3.  **Define Model Classes:**

    *   **`Models/DataModel.cs`** (Represents the structure of `data.json`):
        ```csharp
        // Models/DataModel.cs
        namespace StorageToJsonRelayFunction.Models;

        public class DataModel
        {
            public string? Id { get; set; }
            public string? OriginalMessage { get; set; }
            public int SomeValue { get; set; }
            public DateTime Timestamp { get; set; }
        }
        ```

    *   **`Models/ForwardingPayload.cs`** (Data to be sent to the target function):
        ```csharp
        // Models/ForwardingPayload.cs
        namespace StorageToJsonRelayFunction.Models;

        public class ForwardingPayload
        {
            public string? SourceId { get; set; }
            public string? ProcessedMessage { get; set; }
            public int Value { get; set; }
        }
        ```

4.  **Define Configuration Settings Classes:**

    *   **`Settings/StorageSettings.cs`:**
        ```csharp
        // Settings/StorageSettings.cs
        namespace StorageToJsonRelayFunction.Settings;

        public class StorageSettings
        {
            public const string SectionName = "Storage";
            public string AccountName { get; set; } = string.Empty;
            public string ContainerName { get; set; } = string.Empty;
            public string FileName { get; set; } = "data.json"; // Default file name
        }
        ```

    *   **`Settings/ForwardingSettings.cs`:**
        ```csharp
        // Settings/ForwardingSettings.cs
        namespace StorageToJsonRelayFunction.Settings;

        public class ForwardingSettings
        {
            public const string SectionName = "Forwarding";
            public string TargetFunctionUrl { get; set; } = string.Empty;
            public string? TargetFunctionKey { get; set; } // Nullable, as some functions might use other auth
        }
        ```

5.  **Create Services:**

    *   **`Services/IStorageService.cs`:**
        ```csharp
        // Services/IStorageService.cs
        using StorageToJsonRelayFunction.Models;
        using System.Threading.Tasks;

        namespace StorageToJsonRelayFunction.Services;

        public interface IStorageService
        {
            Task<DataModel?> GetJsonDataAsync();
        }
        ```

    *   **`Services/StorageService.cs`:**
        ```csharp
        // Services/StorageService.cs
        using Azure.Identity;
        using Azure.Storage.Blobs;
        using Microsoft.Extensions.Logging;
        using Microsoft.Extensions.Options;
        using StorageToJsonRelayFunction.Models;
        using StorageToJsonRelayFunction.Settings;
        using System;
        using System.IO;
        using System.Text.Json;
        using System.Threading.Tasks;

        namespace StorageToJsonRelayFunction.Services;

        public class StorageService : IStorageService
        {
            private readonly StorageSettings _settings;
            private readonly ILogger<StorageService> _logger;
            private readonly BlobServiceClient _blobServiceClient;

            public StorageService(IOptions<StorageSettings> settings, ILogger<StorageService> logger)
            {
                _settings = settings.Value;
                _logger = logger;

                if (string.IsNullOrWhiteSpace(_settings.AccountName))
                {
                    throw new ArgumentException("Storage AccountName must be configured.", nameof(settings));
                }

                // Use DefaultAzureCredential for authentication
                // It will try various auth methods: Managed Identity, Azure CLI, VS, etc.
                var blobServiceUri = new Uri($"httpsकर्मियों://{_settings.AccountName}.blob.core.windows.net");
                _blobServiceClient = new BlobServiceClient(blobServiceUri, new DefaultAzureCredential());
            }

            public async Task<DataModel?> GetJsonDataAsync()
            {
                try
                {
                    _logger.LogInformation("Attempting to read {FileName} from container {ContainerName} in storage account {AccountName}.",
                        _settings.FileName, _settings.ContainerName, _settings.AccountName);

                    BlobContainerClient containerClient = _blobServiceClient.GetBlobContainerClient(_settings.ContainerName);
                    BlobClient blobClient = containerClient.GetBlobClient(_settings.FileName);

                    if (!await blobClient.ExistsAsync())
                    {
                        _logger.LogWarning("Blob {FileName} does not exist in container {ContainerName}.", _settings.FileName, _settings.ContainerName);
                        return null;
                    }

                    var response = await blobClient.DownloadStreamingAsync();
                    using var streamReader = new StreamReader(response.Value.Content);
                    string content = await streamReader.ReadToEndAsync();

                    var dataModel = JsonSerializer.Deserialize<DataModel>(content, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                    _logger.LogInformation("Successfully read and deserialized {FileName}.", _settings.FileName);
                    return dataModel;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error reading or deserializing JSON data from blob storage.");
                    return null;
                }
            }
        }
        ```

    *   **`Services/IFunctionOrchestratorService.cs`:**
        ```csharp
        // Services/IFunctionOrchestratorService.cs
        using System.Threading.Tasks;

        namespace StorageToJsonRelayFunction.Services;

        public interface IFunctionOrchestratorService
        {
            Task<bool> ProcessAndForwardDataAsync();
        }
        ```

    *   **`Services/FunctionOrchestratorService.cs`:**
        ```csharp
        // Services/FunctionOrchestratorService.cs
        using Microsoft.Extensions.Logging;
        using Microsoft.Extensions.Options;
        using StorageToJsonRelayFunction.Models;
        using StorageToJsonRelayFunction.Settings;
        using System;
        using System.Net.Http;
        using System.Net.Http.Headers;
        using System.Net.Http.Json; // Requires System.Net.Http.Json NuGet package (often transitive)
        using System.Text.Json;
        using System.Threading.Tasks;

        namespace StorageToJsonRelayFunction.Services;

        public class FunctionOrchestratorService : IFunctionOrchestratorService
        {
            private readonly IStorageService _storageService;
            private readonly ForwardingSettings _forwardingSettings;
            private readonly IHttpClientFactory _httpClientFactory;
            private readonly ILogger<FunctionOrchestratorService> _logger;

            public FunctionOrchestratorService(
                IStorageService storageService,
                IOptions<ForwardingSettings> forwardingSettings,
                IHttpClientFactory httpClientFactory,
                ILogger<FunctionOrchestratorService> logger)
            {
                _storageService = storageService;
                _forwardingSettings = forwardingSettings.Value;
                _httpClientFactory = httpClientFactory;
                _logger = logger;

                if (string.IsNullOrWhiteSpace(_forwardingSettings.TargetFunctionUrl))
                {
                    throw new ArgumentException("TargetFunctionUrl must be configured.", nameof(forwardingSettings));
                }
            }

            public async Task<bool> ProcessAndForwardDataAsync()
            {
                _logger.LogInformation("Starting data processing and forwarding...");
                var data = await _storageService.GetJsonDataAsync();

                if (data == null)
                {
                    _logger.LogWarning("No data retrieved from storage. Aborting forwarding.");
                    return false;
                }

                var payload = new ForwardingPayload
                {
                    SourceId = data.Id,
                    ProcessedMessage = $"Modified: {data.OriginalMessage} - Processed at {DateTime.UtcNow:O}",
                    Value = data.SomeValue
                };

                _logger.LogInformation("Data processed. Forwarding payload to {TargetFunctionUrl}", _forwardingSettings.TargetFunctionUrl);

                try
                {
                    var httpClient = _httpClientFactory.CreateClient("ForwardingClient");
                    var request = new HttpRequestMessage(HttpMethod.Post, _forwardingSettings.TargetFunctionUrl);

                    if (!string.IsNullOrWhiteSpace(_forwardingSettings.TargetFunctionKey))
                    {
                        request.Headers.Add("x-functions-key", _forwardingSettings.TargetFunctionKey);
                        _logger.LogInformation("Added x-functions-key header.");
                    }
                    else
                    {
                        _logger.LogInformation("No TargetFunctionKey provided. Assuming target function uses other auth (e.g., AAD, anonymous).");
                    }

                    request.Content = JsonContent.Create(payload);

                    var response = await httpClient.SendAsync(request);

                    if (response.IsSuccessStatusCode)
                    {
                        _logger.LogInformation("Successfully forwarded data. Target function responded with {StatusCode}.", response.StatusCode);
                        return true;
                    }
                    else
                    {
                        var errorContent = await response.Content.ReadAsStringAsync();
                        _logger.LogError("Failed to forward data. Target function responded with {StatusCode}. Content: {ErrorContent}",
                            response.StatusCode, errorContent);
                        return false;
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error occurred while forwarding data to target function.");
                    return false;
                }
            }
        }
        ```

6.  **Create the Azure Function Trigger:**

    *   **`ProcessStorageDataAndForwardFunction.cs`** (HTTP Trigger for easy testing, could be TimerTrigger):
        ```csharp
        // ProcessStorageDataAndForwardFunction.cs
        using Microsoft.Azure.Functions.Worker;
        using Microsoft.Azure.Functions.Worker.Http;
        using Microsoft.Extensions.Logging;
        using StorageToJsonRelayFunction.Services;
        using System.Net;
        using System.Threading.Tasks;

        namespace StorageToJsonRelayFunction;

        public class ProcessStorageDataAndForwardFunction
        {
            private readonly ILogger<ProcessStorageDataAndForwardFunction> _logger;
            private readonly IFunctionOrchestratorService _orchestratorService;

            public ProcessStorageDataAndForwardFunction(
                ILogger<ProcessStorageDataAndForwardFunction> logger,
                IFunctionOrchestratorService orchestratorService)
            {
                _logger = logger;
                _orchestratorService = orchestratorService;
            }

            [Function("ProcessAndRelayData")]
            public async Task<HttpResponseData> Run(
                [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequestData req)
            {
                _logger.LogInformation("ProcessAndRelayData HTTP trigger function invoked.");

                bool success = await _orchestratorService.ProcessAndForwardDataAsync();

                var response = req.CreateResponse(success ? HttpStatusCode.OK : HttpStatusCode.InternalServerError);
                response.Headers.Add("Content-Type", "application/json; charset=utf-8");

                if (success)
                {
                    await response.WriteStringAsync("{\"status\": \"Data processed and forwarded successfully.\"}");
                }
                else
                {
                    await response.WriteStringAsync("{\"status\": \"Failed to process or forward data. Check logs.\"}");
                }
                return response;
            }
        }
        ```

7.  **Update `Program.cs` for Configuration and DI:**
    ```csharp
    // Program.cs
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Hosting;
    using Microsoft.Extensions.Logging; // For explicit logging config
    using StorageToJsonRelayFunction.Services;
    using StorageToJsonRelayFunction.Settings;
    using System.IO; // Required for Path.GetDirectoryName

    var host = new HostBuilder()
        .ConfigureAppConfiguration((hostingContext, config) =>
        {
            var env = hostingContext.HostingEnvironment;
            var appAssemblyPath = System.Reflection.Assembly.GetExecutingAssembly().Location;

            config.SetBasePath(Path.GetDirectoryName(appAssemblyPath))
                  .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
                  .AddJsonFile($"appsettings.{env.EnvironmentName}.json", optional: true, reloadOnChange: true);

            if (env.IsDevelopment())
            {
                config.AddUserSecrets<Program>(optional: true);
            }
            // Environment variables (from local.settings.json or Azure App Settings) are added by default
            // by ConfigureFunctionsWorkerDefaults or can be added explicitly:
            config.AddEnvironmentVariables();
        })
        .ConfigureFunctionsWorkerDefaults() // Or .ConfigureFunctionsWebApplication() if using ASP.NET Core integration
        .ConfigureServices((hostContext, services) =>
        {
            IConfiguration configuration = hostContext.Configuration;

            // Register strongly-typed settings
            services.Configure<StorageSettings>(configuration.GetSection(StorageSettings.SectionName));
            services.Configure<ForwardingSettings>(configuration.GetSection(ForwardingSettings.SectionName));

            // Register HttpClientFactory
            services.AddHttpClient("ForwardingClient", client =>
            {
                // You can configure default headers or base address here if needed
                // client.Timeout = TimeSpan.FromSeconds(30); // Example
            });

            // Register custom services
            services.AddSingleton<IStorageService, StorageService>();
            services.AddSingleton<IFunctionOrchestratorService, FunctionOrchestratorService>();

            // Example of more granular logging control if needed
            services.AddLogging(loggingBuilder =>
            {
                loggingBuilder.AddConfiguration(configuration.GetSection("Logging"));
                loggingBuilder.AddConsole(); // Add other providers like ApplicationInsights if needed
            });
        })
        .Build();

    host.Run();
    ```

8.  **Configuration Files:**

    *   **`appsettings.json`** (defaults, commit this):
        ```json
        {
          "Logging": {
            "LogLevel": {
              "Default": "Information",
              "Microsoft.Hosting.Lifetime": "Information",
              "StorageToJsonRelayFunction": "Debug" // More verbose for our app
            }
          },
          "Storage": {
            "AccountName": "YOUR_DEFAULT_STORAGE_ACCOUNT_NAME_HERE_IF_ANY", // e.g. some shared dev one
            "ContainerName": "input-data",
            "FileName": "data.json"
          },
          "Forwarding": {
            "TargetFunctionUrl": "https://YOUR_DEFAULT_TARGET_FUNCTION_URL.azurewebsites.net/api/ReceiveDataTrigger"
            // TargetFunctionKey should NOT be here. Use User Secrets or local.settings.json for local, Key Vault for Azure.
          }
        }
        ```
        Ensure "Copy to Output Directory" is set to "Copy if newer" or "Copy always" for `appsettings.json` and any `appsettings.Development.json` in their file properties or `.csproj`:
        ```xml
        <ItemGroup>
          <None Update="appsettings.json">
            <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
          </None>
          <None Update="appsettings.Development.json">
            <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
            <DependentUpon>appsettings.json</DependentUpon>
          </None>
          <!-- Add other appsettings like appsettings.Production.json if needed -->
        </ItemGroup>
        ```

    *   **`appsettings.Development.json`** (local dev overrides, commit this if no secrets):
        ```json
        {
          "Storage": {
            "AccountName": "stcdsoptmzdev" // Example for dev environment
          },
          "Forwarding": {
            "TargetFunctionUrl": "http://localhost:7071/api/MyTargetFunction" // If testing target locally
          }
        }
        ```

    *   **`local.settings.json`** (local Azure Functions host settings, **DO NOT COMMIT if it contains secrets**):
        ```json
        {
          "IsEncrypted": false,
          "Values": {
            "AzureWebJobsStorage": "UseDevelopmentStorage=true", // For Azurite
            "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
            "AZURE_FUNCTIONS_ENVIRONMENT": "Development", // Critical for loading appsettings.Development.json

            // These override appsettings.json and appsettings.Development.json
            "Storage:AccountName": "stcdsoptmzdev", // Your specific dev storage account
            "Storage:ContainerName": "rawdata",     // Your specific container
            "Storage:FileName": "data.json",

            "Forwarding:TargetFunctionUrl": "https://your-actual-dev-target-func.azurewebsites.net/api/YourTargetHttpTrigger",
            // For local dev, you can put the key here or use User Secrets.
            // User Secrets are generally safer if this file might be accidentally committed.
            "Forwarding:TargetFunctionKey": "YOUR_DEV_TARGET_FUNCTION_KEY_HERE"

            // If DefaultAzureCredential needs explicit setup for local dev (e.g. Service Principal):
            // "AZURE_CLIENT_ID": "your-sp-client-id",
            // "AZURE_TENANT_ID": "your-tenant-id",
            // "AZURE_CLIENT_SECRET": "your-sp-client-secret"
          }
        }
        ```
        **Important:** Add `local.settings.json` to your `.gitignore`.

    *   **User Secrets (Optional but Recommended for local `TargetFunctionKey`):**
        Right-click project -> "Manage User Secrets" or CLI:
        ```bash
        dotnet user-secrets init
        dotnet user-secrets set "Forwarding:TargetFunctionKey" "YOUR_LOCAL_DEV_TARGET_FUNCTION_KEY"
        ```
        If you use User Secrets for the key, you can remove it from `local.settings.json`.

9.  **Sample `data.json` for Storage:**
    Create a file named `data.json` with content like this and upload it to your Azure Blob Storage container:
    ```json
    {
      "id": "doc123",
      "originalMessage": "Hello from Blob Storage!",
      "someValue": 42,
      "timestamp": "2023-10-27T10:30:00Z"
    }
    ```

---

**Phase 2: Local Testing**

1.  **Set up Azurite (Storage Emulator):**
    *   Install and run Azurite (e.g., via VS Code extension or Docker).
    *   Ensure `local.settings.json` has `"AzureWebJobsStorage": "UseDevelopmentStorage=true",`.
    *   Create a container (e.g., "rawdata") in Azurite and upload your `data.json`.
    *   Update `local.settings.json` -> `"Storage:AccountName"` to be your Azurite account name (usually `devstoreaccount1` when `UseDevelopmentStorage=true` is fully parsed, but `DefaultAzureCredential` won't use `UseDevelopmentStorage=true` for your custom blob access. Instead, for local testing with Azurite and `DefaultAzureCredential`, you might need to target `127.0.0.1:10000/devstoreaccount1` or ensure your Azure CLI login has access to a real dev storage account).
    *   **Easier for `DefaultAzureCredential` locally:**
        *   Log in with Azure CLI: `az login`
        *   Ensure your logged-in user has "Storage Blob Data Reader" role on the Azure Storage Account specified in `local.settings.json` (`stcdsoptmzdev`).
        *   Upload `data.json` to the `rawdata` container in `stcdsoptmzdev` on Azure.

2.  **Run the Function Locally:**
    ```bash
    func start
    # or F5 in Visual Studio / VS Code
    ```
    Open the URL provided for `ProcessAndRelayData` (e.g., `http://localhost:7071/api/ProcessAndRelayData`) in a browser or Postman. Check the console logs for output.

---

**Phase 3: Deployment with Azure CLI**

This script creates necessary resources and deploys the function.

*   **`deploy-function.sh` (Bash script):**
    ```bash
    #!/bin/bash

    # --- Configuration ---
    RESOURCE_GROUP="rg-cds-optmz-dev"
    LOCATION="eastus" # Or your preferred region
    STORAGE_ACCOUNT_NAME="stcdsoptmzdev$(openssl rand -hex 4)" # Make unique
    FUNCTION_APP_NAME="func-storagerelay-cds-dev-$(openssl rand -hex 4)" # Make unique
    APP_INSIGHTS_NAME="appi-${FUNCTION_APP_NAME}"

    # Target Function - assumed to exist or you'll replace these
    # For a real deployment, TARGET_FUNCTION_KEY would come from Key Vault
    TARGET_FUNCTION_URL_VALUE="https://YOUR_EXISTING_TARGET_FUNCTION.azurewebsites.net/api/YourTargetHttpTriggerName"
    TARGET_FUNCTION_KEY_VALUE="YOUR_TARGET_FUNCTION_KEY_FOR_DEV_ENV" # Replace or manage via Key Vault later

    # Blob Storage details (where data.json is)
    DATA_STORAGE_ACCOUNT_NAME="stcdsoptmzdev" # The account where data.json resides
    DATA_STORAGE_CONTAINER_NAME="rawdata"
    DATA_STORAGE_FILE_NAME="data.json"

    # --- Script ---
    echo "Starting Azure Function deployment..."

    # 1. Create Resource Group (if not exists)
    echo "Creating/Updating resource group: $RESOURCE_GROUP"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o none

    # 2. Create Storage Account for Function App (if not exists)
    # This is for the Function App's own operational storage, NOT necessarily where data.json is.
    echo "Creating storage account for Function App: $STORAGE_ACCOUNT_NAME"
    az storage account create \
      --name "$STORAGE_ACCOUNT_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --location "$LOCATION" \
      --sku Standard_LRS \
      --kind StorageV2 \
      -o none

    # 3. Create Application Insights (optional but recommended)
    echo "Creating Application Insights: $APP_INSIGHTS_NAME"
    az monitor app-insights component create \
      --app "$APP_INSIGHTS_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --location "$LOCATION" \
      --kind web \
      -o none
    APP_INSIGHTS_KEY=$(az monitor app-insights component show --app "$APP_INSIGHTS_NAME" -g "$RESOURCE_GROUP" --query "instrumentationKey" -o tsv)


    # 4. Create Function App
    echo "Creating Function App: $FUNCTION_APP_NAME"
    az functionapp create \
      --name "$FUNCTION_APP_NAME" \
      --storage-account "$STORAGE_ACCOUNT_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --consumption-plan-location "$LOCATION" \
      --runtime dotnet-isolated \
      --runtime-version 9.0 \
      --functions-version 4 \
      --os-type Windows \
      --assign-identity "[system]" \
      --app-insights "$APP_INSIGHTS_NAME" \
      --app-insights-key "$APP_INSIGHTS_KEY" \
      -o none

    echo "Function App created. Waiting a bit for identity to propagate..."
    sleep 30 # Give Azure time to provision the managed identity

    # 5. Grant Managed Identity access to the DATA Storage Account
    # Get the Principal ID of the Function App's System-Assigned Managed Identity
    FUNC_PRINCIPAL_ID=$(az functionapp identity show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "principalId" -o tsv)

    if [ -z "$FUNC_PRINCIPAL_ID" ] || [ "$FUNC_PRINCIPAL_ID" == "null" ]; then
        echo "ERROR: Could not retrieve Principal ID for Function App. Exiting."
        exit 1
    fi
    echo "Function App Principal ID: $FUNC_PRINCIPAL_ID"

    # Get the Resource ID of the DATA Storage Account
    DATA_STORAGE_ACCOUNT_ID=$(az storage account show --name "$DATA_STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --query "id" -o tsv)
    if [ -z "$DATA_STORAGE_ACCOUNT_ID" ]; then
        echo "ERROR: Could not retrieve Resource ID for Data Storage Account '$DATA_STORAGE_ACCOUNT_NAME'. Ensure it exists in '$RESOURCE_GROUP'."
        exit 1
    fi
    echo "Data Storage Account ID: $DATA_STORAGE_ACCOUNT_ID"

    echo "Assigning 'Storage Blob Data Reader' role to Function App's Managed Identity on Data Storage Account..."
    az role assignment create \
      --assignee "$FUNC_PRINCIPAL_ID" \
      --role "Storage Blob Data Reader" \
      --scope "$DATA_STORAGE_ACCOUNT_ID" \
      -o none
    echo "Role assignment complete."

    # 6. Configure Function App Settings
    # For production, TargetFunctionKey should be a Key Vault reference
    echo "Configuring App Settings for $FUNCTION_APP_NAME..."
    az functionapp config appsettings set --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" \
      --settings \
        "AZURE_FUNCTIONS_ENVIRONMENT=Development" \
        "FUNCTIONS_WORKER_RUNTIME=dotnet-isolated" \
        "Storage__AccountName=$DATA_STORAGE_ACCOUNT_NAME" \
        "Storage__ContainerName=$DATA_STORAGE_CONTAINER_NAME" \
        "Storage__FileName=$DATA_STORAGE_FILE_NAME" \
        "Forwarding__TargetFunctionUrl=$TARGET_FUNCTION_URL_VALUE" \
        "Forwarding__TargetFunctionKey=$TARGET_FUNCTION_KEY_VALUE" \
        "APPINSIGHTS_INSTRUMENTATIONKEY=$APP_INSIGHTS_KEY" \
      -o none
    echo "App Settings configured."

    # 7. Deploy the Function App code
    # Ensure you are in the project root directory (StorageToJsonRelayFunction)
    echo "Building the project..."
    dotnet publish -c Release -o ./publish_output

    echo "Deploying Function App code from ./publish_output..."
    cd ./publish_output || exit
    zip -r ../deploy.zip .
    cd ..

    az functionapp deployment source config-zip \
      --name "$FUNCTION_APP_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --src "./deploy.zip" \
      -o none

    echo "Deployment submitted."
    echo "Function App URL: https://$FUNCTION_APP_NAME.azurewebsites.net"
    echo "To invoke: https://$FUNCTION_APP_NAME.azurewebsites.net/api/ProcessAndRelayData (may require function key based on HttpTrigger auth level)"

    # Clean up build artifacts
    rm -rf ./publish_output
    rm ./deploy.zip

    echo "Script finished."
    ```
    **Before running:**
    *   Make sure `DATA_STORAGE_ACCOUNT_NAME` (`stcdsoptmzdev`) and `RESOURCE_GROUP` (`rg-cds-optmz-dev`) exist and you have permissions.
    *   The script *creates* a new storage account for the function app itself. The `DATA_STORAGE_ACCOUNT_NAME` is where your `data.json` lives.
    *   Replace `TARGET_FUNCTION_URL_VALUE` and `TARGET_FUNCTION_KEY_VALUE` with actual values for your dev environment.
    *   Run `chmod +x deploy-function.sh` and then `./deploy-function.sh`.

---

**Phase 4: Azure DevOps YAML Pipeline Update**

The pipeline will now need to handle:
*   The specific settings for this function.
*   Setting up Key Vault references for secrets like `TargetFunctionKey`.

**Updated `azure-pipelines.yml`:**

```yaml
trigger:
- main

pool:
  vmImage: 'windows-latest' # Or 'ubuntu-latest'

variables:
- name: buildConfiguration
  value: 'Release'
- name: dotnetVersion
  value: '9.0.x'
- name: functionAppNameBase # Base name, environment will be appended
  value: 'func-storagerelay-cds'
- name: dataStorageAccountName # The storage account where data.json is located
  value: 'stcdsoptmzdev' # This should be consistent for the dev env or configured per env
- name: dataStorageContainerName
  value: 'rawdata'
- name: dataStorageFileName
  value: 'data.json'

stages:
- stage: Build
  jobs:
  - job: BuildJob
    steps:
    - task: UseDotNet@2
      displayName: 'Use .NET SDK $(dotnetVersion)'
      inputs:
        packageType: 'sdk'
        version: '$(dotnetVersion)'

    - task: DotNetCoreCLI@2
      displayName: 'Restore, Build, Publish Function App'
      inputs:
        command: 'publish'
        publishWebProjects: false
        projects: '**/StorageToJsonRelayFunction.csproj' # Path to your csproj
        arguments: '--configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)/App --runtime win-x64 --self-contained false'
        zipAfterPublish: true

    - task: PublishBuildArtifacts@1
      displayName: 'Publish Artifact: App'
      inputs:
        PathtoPublish: '$(Build.ArtifactStagingDirectory)/App'
        ArtifactName: 'App'
        publishLocation: 'Container'

- stage: DeployDev
  displayName: 'Deploy to Development'
  dependsOn: Build
  condition: succeeded()
  variables:
  - group: StorageRelayFunction-Dev-Vars # Variable group for DEV
    # This group should contain:
    # DevTargetFunctionUrl: (your dev target function URL)
    # DevTargetFunctionKeySecretUri: (Key Vault Secret URI for the target function key)
    # DevFunctionAppName: (e.g., func-storagerelay-cds-dev)
  jobs:
  - deployment: DeployFunctionAppDev
    environment: 'StorageRelayFunction-Development' # Azure DevOps Environment
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureFunctionApp@2
            displayName: 'Deploy Azure Function App to Dev'
            inputs:
              azureSubscription: 'Your-Azure-Dev-Subscription-Service-Connection'
              appType: 'functionApp'
              appName: '$(DevFunctionAppName)' # From Variable Group or define directly
              package: '$(Pipeline.Workspace)/App/**/*.zip'
              deploymentMethod: 'auto'
              appSettings: >-
                -AZURE_FUNCTIONS_ENVIRONMENT "Development"
                -Storage__AccountName "$(dataStorageAccountName)"
                -Storage__ContainerName "$(dataStorageContainerName)"
                -Storage__FileName "$(dataStorageFileName)"
                -Forwarding__TargetFunctionUrl "$(DevTargetFunctionUrl)"
                -Forwarding__TargetFunctionKey "@Microsoft.KeyVault(SecretUri=$(DevTargetFunctionKeySecretUri))"
              # Ensure Function App has Managed Identity enabled and role assignment for dataStorageAccountName

# --- Similar stages for Test, UAT, Prod ---
# Example for Prod (ensure approvals are set on the 'StorageRelayFunction-Production' ADO Environment)
- stage: DeployProd
  displayName: 'Deploy to Production'
  dependsOn: DeployDev # Or DeployUAT if you have it
  condition: succeeded() # And potentially manual approval on the environment
  variables:
  - group: StorageRelayFunction-Prod-Vars # Variable group for PROD
    # This group should contain:
    # ProdTargetFunctionUrl: (your prod target function URL)
    # ProdTargetFunctionKeySecretUri: (Key Vault Secret URI for the prod target function key)
    # ProdFunctionAppName: (e.g., func-storagerelay-cds-prod)
  jobs:
  - deployment: DeployFunctionAppProd
    environment: 'StorageRelayFunction-Production'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureFunctionApp@2
            displayName: 'Deploy Azure Function App to Prod'
            inputs:
              azureSubscription: 'Your-Azure-Prod-Subscription-Service-Connection'
              appType: 'functionApp'
              appName: '$(ProdFunctionAppName)'
              package: '$(Pipeline.Workspace)/App/**/*.zip'
              deploymentMethod: 'runFromPackage' # Recommended for prod
              appSettings: >-
                -AZURE_FUNCTIONS_ENVIRONMENT "Production"
                -Storage__AccountName "$(dataStorageAccountName)" # Or make this env-specific too
                -Storage__ContainerName "$(dataStorageContainerName)"
                -Storage__FileName "$(dataStorageFileName)"
                -Forwarding__TargetFunctionUrl "$(ProdTargetFunctionUrl)"
                -Forwarding__TargetFunctionKey "@Microsoft.KeyVault(SecretUri=$(ProdTargetFunctionKeySecretUri))"

```

**Azure DevOps Variable Groups Setup:**

For each environment (e.g., `StorageRelayFunction-Dev-Vars`):
1.  Create the Variable Group in Azure DevOps (Pipelines -> Library).
2.  **Link to Azure Key Vault:**
    *   Toggle "Link secrets from an Azure key vault as variables".
    *   Select Azure subscription and the *Key Vault for that environment* (e.g., `kv-cds-optmz-dev`).
    *   Add secrets from Key Vault. For example, if your Key Vault secret for the dev target function key is named `TargetFuncDevKey`, you'd add it. The pipeline variable might then be named `TargetFuncDevKey` or you could give it an alias in the variable group.
    *   In the YAML, you then reference it like `$(DevTargetFunctionKeySecretUri)`. This variable in the group should hold the full Secret URI from Key Vault: `https://your-kv-name.vault.azure.net/secrets/YourSecretName/YourSecretVersionGuid`. *Or, better, if your Key Vault is linked and you add the secret `MySecretNameFromKV` to the variable group, you can directly use `@Microsoft.KeyVault(VaultName=yourKVNameInVG;SecretName=MySecretNameFromKV)` if the AzureFunctionApp task supports this simplified syntax for linked KVs. If not, store the full Secret URI as a variable in the VG.* The most robust way is to have a variable in the VG like `DevTargetFunctionKeySecretUri` whose *value* is the actual Secret URI from Key Vault.
3.  **Add Non-Secret Variables:**
    *   `DevTargetFunctionUrl`: `https://dev-target-func.azurewebsites.net/api/MyTrigger`
    *   `DevFunctionAppName`: `func-storagerelay-cds-dev`
    *   If `dataStorageAccountName` changes per environment, add it here too.

**Important for Pipeline Deployment & Managed Identity:**
*   The Function App deployed by the pipeline **must have a System-Assigned or User-Assigned Managed Identity**. This is usually configured when the Function App is first provisioned (e.g., via ARM/Bicep template or initial `az functionapp create --assign-identity`).
*   This Managed Identity **must be granted the "Storage Blob Data Reader" role** on the `DATA_STORAGE_ACCOUNT_NAME` (`stcdsoptmzdev` in this example). This role assignment needs to be done once per environment. It can be done manually, via `az cli` (as in the `deploy-function.sh` script), or as part of your Infrastructure as Code (IaC) setup.

This detailed setup provides a full cycle from local development to CI/CD deployment using best practices for configuration and Azure resource interaction. Remember to replace placeholders with your actual resource names, URLs, and service connection names.

#### When the func is not loaded

The command `dotnet new func` relies on the **Azure Functions Core Tools** templates being installed and recognized by the `dotnet new` command system.

The error message "No templates or sub commands found matching: 'func'" clearly indicates that the .NET CLI cannot find the Azure Functions project templates. This usually means the Azure Functions Core Tools (which provide these templates) are either not installed, or their templates haven't been properly registered with `dotnet new`.


**Step 1: Install/Update Azure Functions Core Tools**

The Azure Functions Core Tools are required for local Azure Functions development and provide the necessary project templates. The recommended way to install them often depends on your OS and preferences, but using `npm` is a common cross-platform method.

**Option A: Using npm (Node Package Manager - Recommended for cross-platform)**

1.  **Install Node.js and npm:** If you don't have Node.js and npm installed, download and install them from [https://nodejs.org/](https://nodejs.org/). LTS version is usually fine.
2.  **Install or Update Azure Functions Core Tools:**
    Open your terminal or command prompt and run:
    ```bash
    npm install -g azure-functions-core-tools@4 --unsafe-perm true
    ```
    *   `@4` specifies version 4.x, which is the current major version for Azure Functions V4 runtime (compatible with .NET 6, 7, 8, and upcoming .NET 9).
    *   `--unsafe-perm true` is sometimes needed on Linux/macOS for global installs to handle permissions correctly.

**Option B: Using Chocolatey (Windows)**

1.  **Install Chocolatey:** If you don't have it, follow instructions at [https://chocolatey.org/install](https://chocolatey.org/install).
2.  **Install Azure Functions Core Tools:**
    ```bash
    choco install azure-functions-core-tools
    ```

**Option C: Using Homebrew (macOS)**

1.  **Install Homebrew:** If you don't have it, follow instructions at [https://brew.sh/](https://brew.sh/).
2.  **Install Azure Functions Core Tools:**
    ```bash
    brew tap azure/functions
    brew install azure-functions-core-tools@4
    ```

**Option D: Platform-Specific Installers (Windows MSI)**

You can also download the MSI installer directly from the [Azure Functions Core Tools GitHub releases page](https://github.com/Azure/azure-functions-core-tools/releases). Look for `Azure.Functions.Cli.*.x64.msi`.

**Step 2: Verify Core Tools Installation and `dotnet new` Templates**

1.  **Close and Reopen your Terminal/Command Prompt:** This is crucial to ensure that any PATH changes made by the installer take effect.
2.  **Verify `func` command:**
    ```bash
    func --version
    ```
    You should see an output like `4.x.xxxx`.
3.  **Check `dotnet new` list for function templates:**
    ```bash
    dotnet new list function
    ```
    Or, more broadly:
    ```bash
    dotnet new list
    ```
    You should now see Azure Functions templates listed, such as:
    *   `Azure Functions` (func)
    *   `Http Trigger` (HttpTrigger)
    *   `Timer Trigger` (TimerTrigger)
    *   etc.

    If they are still missing after installing/reinstalling Core Tools and restarting the terminal, you might need to manually install the templates:
    ```bash
    dotnet new install Microsoft.Azure.WebJobs.ItemTemplates
    dotnet new install Microsoft.Azure.WebJobs.ProjectTemplates
    ```
    Then check `dotnet new list` again.

**Step 3: Re-run the Project Creation Command**

Once you've confirmed the Azure Functions Core Tools are installed and the templates are available, the original command should work:

```bash
dotnet new func --isolated-worker --target-framework net9.0 -o StorageToJsonRelayFunction
cd StorageToJsonRelayFunction
```

**Reasoning for the Original Error & Fix:**

The `dotnet new` command system is extensible. Different SDKs and tools (like Azure Functions Core Tools) can provide their own templates. When you run `dotnet new <template-short-name>`, the CLI looks for installed templates matching that short name. `func` is the short name for the main Azure Functions project template. If the Core Tools (which supply this template) aren't installed or their template manifest isn't registered, `dotnet new` won't find it.

By installing the Azure Functions Core Tools, you're not just getting the `func` CLI for running functions locally, but you're also installing the necessary project and item templates that integrate with `dotnet new`.

Thank you for catching that! It's a common prerequisite that's easy to overlook when jumping straight into the `dotnet new` command.
