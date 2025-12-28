### Best Practices for managing application and environment-specific variables for .NET 9.0 C# 12 Azure Functions (Isolated Worker model), covering local development and Azure DevOps deployments across multiple environments.

**Core Principles:**

1.  **Configuration Providers:** Leverage the standard .NET configuration system (`Microsoft.Extensions.Configuration`).
2.  **Hierarchy of Configuration:** Understand that settings can be overridden (e.g., environment variables override `appsettings.json`).
3.  **Secrets Management:** Use Azure Key Vault for all secrets in Azure. For local development, use User Secrets or `local.settings.json` (with caution for secrets).
4.  **Environment Consistency:** Aim to use the same configuration mechanisms locally and in Azure as much as possible.
5.  **Infrastructure as Code (IaC) & DevOps:** Manage Azure resources and deployments through pipelines.

**Configuration Sources Order (Typical for Isolated Worker):**

1.  `appsettings.json` (shared defaults)
2.  `appsettings.{EnvironmentName}.json` (e.g., `appsettings.Development.json`)
3.  User Secrets (local development, overrides `appsettings.*.json`)
4.  `local.settings.json` (specifically for Azure Functions local development, its `Values` map to environment variables)
5.  Environment Variables (OS level, or Azure App Settings in the cloud - these override all previous file-based settings)
6.  Azure Key Vault (via Key Vault references in App Settings, effectively acting as secure environment variables)
7.  Command-line arguments (less common for Functions).

---

**Step-by-Step Guide:**

**Phase 1: Project Setup & Local Development**

1.  **Create Azure Function Project (Isolated Worker):**
    *   Use Visual Studio or the .NET CLI:
        ```bash
        dotnet new func --isolated-worker --target-framework net9.0 -n MyFunctionApp
        cd MyFunctionApp
        ```

2.  **Install Necessary NuGet Packages:**
    The isolated worker SDK usually brings in `Microsoft.Extensions.Configuration` basics. If you need more specific providers:
    ```bash
    dotnet add package Microsoft.Extensions.Configuration.Json
    dotnet add package Microsoft.Extensions.Options.ConfigurationExtensions
    dotnet add package Microsoft.Extensions.DependencyInjection # Usually already there
    # For User Secrets (local dev)
    dotnet add package Microsoft.Extensions.Configuration.UserSecrets
    ```

3.  **Configure `Program.cs` for Rich Configuration:**
    Modify your `Program.cs` to build a configuration that includes `appsettings.json`, environment-specific `appsettings.{Environment}.json`, User Secrets (for local dev), and environment variables.

    ```csharp
    // Program.cs
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Hosting;
    using System.IO; // Required for Path.GetDirectoryName and Assembly

    var host = new HostBuilder()
        .ConfigureAppConfiguration((hostingContext, config) =>
        {
            var env = hostingContext.HostingEnvironment; // IHostEnvironment
            var appAssembly = System.Reflection.Assembly.GetExecutingAssembly().Location;

            config.SetBasePath(Path.GetDirectoryName(appAssembly)) // Crucial for Functions
                  .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
                  .AddJsonFile($"appsettings.{env.EnvironmentName}.json", optional: true, reloadOnChange: true);

            if (env.IsDevelopment())
            {
                // For local development, User Secrets are a good practice for sensitive data
                // not suitable for local.settings.json if it's ever committed by mistake.
                config.AddUserSecrets<Program>(optional: true);
            }

            // local.settings.json values are automatically loaded as environment variables
            // by the Azure Functions Host when running locally.
            // Environment variables (including those from local.settings.json and Azure App Settings)
            // are added by default by ConfigureFunctionsWorkerDefaults or ConfigureFunctionsWebApplication
            // and will override appsettings files.
            // You can explicitly add them too if needed: config.AddEnvironmentVariables();
        })
        .ConfigureFunctionsWorkerDefaults() // Or .ConfigureFunctionsWebApplication() if using ASP.NET Core integration
        .ConfigureServices((hostContext, services) =>
        {
            // Get configuration instance
            IConfiguration configuration = hostContext.Configuration;

            // Option 1: Register strongly-typed settings (Best Practice)
            services.Configure<MyApplicationSettings>(configuration.GetSection("MyApplication"));
            services.Configure<MyEnvironmentSpecificSettings>(configuration.GetSection("EnvironmentSpecific"));

            // Option 2: Register IConfiguration directly if needed (less type-safe)
            // services.AddSingleton(configuration);

            // Register your services
            services.AddSingleton<IMyService, MyService>();
            // ... other services
        })
        .Build();

    host.Run();

    // Define your settings classes
    public class MyApplicationSettings
    {
        public string? ApiKey { get; set; }
        public string? ServiceUrl { get; set; }
        public int DefaultTimeoutSeconds { get; set; }
    }

    public class MyEnvironmentSpecificSettings
    {
        public string? DatabaseConnectionString { get; set; }
        public string? StorageAccountName { get; set; }
    }
    ```
    *   **Note on `SetBasePath`:** For Azure Functions, especially when deployed, setting the base path explicitly to the assembly's directory ensures `appsettings.json` files are found correctly. `Directory.GetCurrentDirectory()` can be unreliable in the Azure Functions runtime environment.

4.  **Create `appsettings.json`:**
    This file contains default or shared settings.
    ```json
    // appsettings.json
    {
      "MyApplication": {
        "ServiceUrl": "https://default.api.example.com",
        "DefaultTimeoutSeconds": 30
      },
      "EnvironmentSpecific": {
        "StorageAccountName": "commondatastorage"
      },
      "Logging": { // Example, can be configured here too
        "LogLevel": {
          "Default": "Information",
          "Microsoft.Hosting.Lifetime": "Information"
        }
      }
    }
    ```
    Ensure "Copy to Output Directory" is set to "Copy if newer" or "Copy always" for these JSON files in their properties in Visual Studio, or via the `.csproj` file:
    ```xml
    <ItemGroup>
        <None Update="appsettings.json">
            <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
        </None>
        <None Update="appsettings.Development.json">
            <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
            <DependentUpon>appsettings.json</DependentUpon>
        </None>
        <None Update="appsettings.Production.json"> <!-- Or UAT, Test etc. -->
            <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
            <DependentUpon>appsettings.json</DependentUpon>
        </None>
    </ItemGroup>
    ```

5.  **Create `appsettings.Development.json`:**
    This overrides settings for the "Development" environment.
    ```json
    // appsettings.Development.json
    {
      "MyApplication": {
        "ServiceUrl": "https://dev.api.example.com"
      },
      "EnvironmentSpecific": {
        "DatabaseConnectionString": "DevelopmentDB_ConnectionString", // Still better in User Secrets or local.settings.json
        "StorageAccountName": "devdatastorage"
      }
    }
    ```

6.  **Set up User Secrets (for sensitive local dev data):**
    *   Right-click the project in Visual Studio -> "Manage User Secrets". Or via CLI:
        ```bash
        dotnet user-secrets init
        dotnet user-secrets set "MyApplication:ApiKey" "MY_LOCAL_DEV_API_KEY_SECRET"
        dotnet user-secrets set "EnvironmentSpecific:DatabaseConnectionString" "local_dev_db_connection_string_from_user_secrets"
        ```
    *   This creates a `secrets.json` file outside your project directory, specific to your user profile.

7.  **Understand `local.settings.json`:**
    This file is primarily for the Azure Functions Core Tools when running *locally*.
    *   **`IsEncrypted`**: Set to `false` for local dev.
    *   **`Values`**: These key-value pairs are loaded as *environment variables* for your local function host. They will override settings from `appsettings.json` and `appsettings.Development.json`.
    *   **`Host`**: Settings for the Functions host itself (e.g., `CORS`, `CORSCredentials`).
    *   **`ConnectionStrings`**: Can be used for connection strings.

    ```json
    // local.settings.json
    {
      "IsEncrypted": false,
      "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true", // For localAzurite
        "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
        "AZURE_FUNCTIONS_ENVIRONMENT": "Development", // This sets IHostEnvironment.EnvironmentName

        // These will override appsettings.*.json and User Secrets if keys match
        // Because they become environment variables
        "MyApplication:ApiKey": "LOCAL_SETTINGS_API_KEY", // Example: if you prefer it here over User Secrets
        "EnvironmentSpecific:DatabaseConnectionString": "Server=(localdb)\\mssqllocaldb;Database=MyLocalDevDb;Trusted_Connection=True;"
        // "MyKeyVaultUri": "https://my-dev-kv.vault.azure.net/" // For local Key Vault access if needed
      },
      "ConnectionStrings": { // Alternative way to define connection strings
          // "MyDbConnection": "local_db_connection_string_from_local_settings"
      }
    }
    ```
    **IMPORTANT:** Add `local.settings.json` to your `.gitignore` file if it contains any real secrets. It's common to commit a `local.settings.json.template` or `local.settings.sample.json` with placeholder values.

8.  **Accessing Configuration in your Function:**
    Use Dependency Injection and the Options pattern.

    ```csharp
    // MyHttpFunction.cs
    using Microsoft.Azure.Functions.Worker;
    using Microsoft.Azure.Functions.Worker.Http;
    using Microsoft.Extensions.Logging;
    using Microsoft.Extensions.Options;
    using System.Net;

    public class MyHttpFunction
    {
        private readonly ILogger<MyHttpFunction> _logger;
        private readonly MyApplicationSettings _appSettings;
        private readonly MyEnvironmentSpecificSettings _envSettings;
        private readonly IMyService _myService;

        // Inject IOptions<T>
        public MyHttpFunction(
            ILogger<MyHttpFunction> logger,
            IOptions<MyApplicationSettings> appSettings,
            IOptions<MyEnvironmentSpecificSettings> envSettings,
            IMyService myService)
        {
            _logger = logger;
            _appSettings = appSettings.Value; // Get the actual settings object
            _envSettings = envSettings.Value;
            _myService = myService;
        }

        [Function("MyHttpTrigger")]
        public async Task<HttpResponseData> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequestData req)
        {
            _logger.LogInformation("C# HTTP trigger function processed a request.");
            _logger.LogInformation("ServiceUrl from config: {ServiceUrl}", _appSettings.ServiceUrl);
            _logger.LogInformation("DefaultTimeoutSeconds from config: {Timeout}", _appSettings.DefaultTimeoutSeconds);
            _logger.LogInformation("ApiKey from config: {ApiKey}", _appSettings.ApiKey); // Will be null if not set anywhere
            _logger.LogInformation("DatabaseConnectionString from config: {DbConn}", _envSettings.DatabaseConnectionString);
            _logger.LogInformation("StorageAccountName from config: {StorageName}", _envSettings.StorageAccountName);

            var message = await _myService.DoSomethingAsync();

            var response = req.CreateResponse(HttpStatusCode.OK);
            response.Headers.Add("Content-Type", "text/plain; charset=utf-8");
            await response.WriteStringAsync($"Welcome to Azure Functions! Message: {message}");
            return response;
        }
    }

    public interface IMyService { Task<string> DoSomethingAsync(); }
    public class MyService : IMyService
    {
        private readonly string _apiKey;
        public MyService(IOptions<MyApplicationSettings> appSettings)
        {
             // Example of accessing specific value if needed directly in a service
            _apiKey = appSettings.Value.ApiKey ?? throw new ArgumentNullException("ApiKey is missing");
        }
        public Task<string> DoSomethingAsync() => Task.FromResult($"Service used API key starting with: {_apiKey.Substring(0, Math.Min(5, _apiKey.Length))}");
    }
    ```

9.  **Running Locally:**
    *   Set `AZURE_FUNCTIONS_ENVIRONMENT` in `local.settings.json` to "Development" (or "Test", "UAT" if you want to test other `appsettings.{env}.json` files locally).
    *   The Functions Host will read `local.settings.json` and make its `Values` available as environment variables.
    *   Your `Program.cs` configuration setup will then correctly load `appsettings.json`, `appsettings.Development.json`, User Secrets, and then these environment variables (from `local.settings.json`) will take final precedence for any overlapping keys.

**Phase 2: Azure Deployment & Configuration**

1.  **Azure Key Vault Setup:**
    *   For each environment (dev, test, uat, prod), create a separate Azure Key Vault instance (e.g., `myfunc-dev-kv`, `myfunc-test-kv`, `myfunc-prod-kv`).
    *   Store all secrets (API keys, connection strings, etc.) in these Key Vaults.
        *   Example Secret Name in Key Vault: `MyApplication--ApiKey` (use double underscore `--` for section nesting, as it translates to `:` in configuration).
        *   Another: `EnvironmentSpecific--DatabaseConnectionString`

2.  **Azure Function App Configuration (App Settings):**
    When you deploy your Function App to Azure, you configure it using "Application Settings" in the Azure portal (or via ARM/Bicep/Terraform).
    *   **`AZURE_FUNCTIONS_ENVIRONMENT`**: Set this App Setting to `Development`, `Test`, `UAT`, or `Production` for the respective Function App instance. This controls which `appsettings.{EnvironmentName}.json` file is loaded if present, and also the `env.IsDevelopment()`, `env.IsProduction()` checks in `Program.cs`.
    *   **Non-Sensitive Settings:** Can be set directly as App Settings.
        *   `MyApplication:ServiceUrl` = `https://prod.api.example.com`
        *   `MyApplication:DefaultTimeoutSeconds` = `60`
    *   **Sensitive Settings (Key Vault References):** This is the best practice.
        *   Grant your Function App's Managed Identity (System-Assigned or User-Assigned) `Get` (and sometimes `List`) permissions on secrets in the corresponding Key Vault.
        *   In the Function App's Application Settings, use Key Vault reference syntax:
            *   Name: `MyApplication:ApiKey`
            *   Value: `@Microsoft.KeyVault(SecretUri=https://myfunc-prod-kv.vault.azure.net/secrets/MyApplication--ApiKey/YOUR_SECRET_VERSION_GUID)`
            *   Or, for latest version: `@Microsoft.KeyVault(VaultName=myfunc-prod-kv;SecretName=MyApplication--ApiKey)`
            *   Similarly for `EnvironmentSpecific:DatabaseConnectionString`.
        *   These App Settings (sourced from Key Vault) become environment variables in the Function App's runtime, overriding any values from `appsettings.*.json` files.

3.  **`.gitignore`:**
    Ensure these are in your `.gitignore`:
    ```
    # Local settings
    local.settings.json
    
    # User Secrets
    **/secrets.json 
    
    # Binaries and build artifacts
    [Bb]in/
    [Oo]bj/
    ```
    You *should* commit `appsettings.json` and potentially `appsettings.Development.json` (if it contains no secrets), `appsettings.Production.json` etc., if they define structural or default non-sensitive configurations. Secrets *always* go into Key Vault for Azure environments.

**Phase 3: Azure DevOps YAML Pipelines**

Here's how to manage environment-specific configurations in Azure DevOps:

1.  **Variable Groups:**
    *   Create Variable Groups for each environment (e.g., `MyFunctionApp-Dev-Vars`, `MyFunctionApp-Test-Vars`, `MyFunctionApp-UAT-Vars`, `MyFunctionApp-Prod-Vars`).
    *   **Option A (Recommended for Secrets): Link to Azure Key Vault.**
        *   In your Variable Group, toggle "Link secrets from an Azure Key Vault as variables".
        *   Select your Azure Subscription and the appropriate Key Vault (e.g., `myfunc-dev-kv` for the dev variable group).
        *   Authorize the connection.
        *   Add the specific secrets you want to pull (e.g., `MyApplication--ApiKey`, `EnvironmentSpecific--DatabaseConnectionString`). These will become pipeline variables.
    *   **Option B (For Non-Secrets): Define Variables Directly.**
        *   You can define non-sensitive variables directly in the group (e.g., `serviceUrl`, `timeout`).

2.  **YAML Pipeline (`azure-pipelines.yml`):**

    ```yaml
    trigger:
    - main # Or your main branch

    pool:
      vmImage: 'windows-latest' # Or 'ubuntu-latest' if your tools support it

    variables:
    - name: buildConfiguration # For dotnet build/publish
      value: 'Release'
    - name: dotnetVersion
      value: '9.0.x' # Specify your .NET version

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

        - script: dotnet build --configuration $(buildConfiguration)
          displayName: 'Build solution'

        - task: DotNetCoreCLI@2
          displayName: 'Publish Function App'
          inputs:
            command: 'publish'
            publishWebProjects: false # Important for Functions
            projects: '**/*.csproj' # Adjust if needed, point to your Function App csproj
            arguments: '--configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)/App --runtime win-x64 --self-contained false' # Adjust runtime as needed
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
      condition: succeeded() # Or specific branch conditions
      variables:
      - group: MyFunctionApp-Dev-Vars # Link your DEV variable group
      jobs:
      - deployment: DeployFunctionAppDev
        environment: 'MyFunctionApp-Development' # Azure DevOps Environment
        strategy:
          runOnce:
            deploy:
              steps:
              - task: AzureFunctionApp@2 # Use version 2 or higher
                displayName: 'Deploy Azure Function App to Dev'
                inputs:
                  azureSubscription: 'Your-Azure-Dev-Subscription-Service-Connection'
                  appType: 'functionApp' # For Windows or functionAppLinux for Linux
                  appName: 'my-dev-functionapp-name' # Your Function App name in Azure
                  package: '$(Pipeline.Workspace)/App/**/*.zip'
                  deploymentMethod: 'auto' # Or zipDeploy, runFromPackage
                  appSettings: >-
                    -AZURE_FUNCTIONS_ENVIRONMENT "Development"
                    -MyApplication:ServiceUrl "$(devServiceUrl)"
                    -MyApplication:ApiKey "@Microsoft.KeyVault(SecretUri=$(DevApiKeySecretUri))"
                    -EnvironmentSpecific:DatabaseConnectionString "@Microsoft.KeyVault(SecretUri=$(DevDbConnSecretUri))"
                    # Add other non-secret settings or Key Vault references here from your variable group
                    # Example: -MyApplication:DefaultTimeoutSeconds "$(devDefaultTimeout)"
                  # If using Key Vault references extensively, you might pre-configure them in ARM/Bicep
                  # and only set AZURE_FUNCTIONS_ENVIRONMENT here.

    - stage: DeployTest
      displayName: 'Deploy to Test'
      dependsOn: Build # Or DeployDev if you want sequential deployment
      condition: succeeded() # And potentially other conditions (e.g., approval, branch)
      variables:
      - group: MyFunctionApp-Test-Vars
      jobs:
      - deployment: DeployFunctionAppTest
        environment: 'MyFunctionApp-Test'
        strategy:
          runOnce:
            deploy:
              steps:
              - task: AzureFunctionApp@2
                displayName: 'Deploy Azure Function App to Test'
                inputs:
                  azureSubscription: 'Your-Azure-Test-Subscription-Service-Connection'
                  appType: 'functionApp'
                  appName: 'my-test-functionapp-name'
                  package: '$(Pipeline.Workspace)/App/**/*.zip'
                  deploymentMethod: 'auto'
                  appSettings: >-
                    -AZURE_FUNCTIONS_ENVIRONMENT "Test"
                    -MyApplication:ServiceUrl "$(testServiceUrl)"
                    -MyApplication:ApiKey "@Microsoft.KeyVault(SecretUri=$(TestApiKeySecretUri))"
                    -EnvironmentSpecific:DatabaseConnectionString "@Microsoft.KeyVault(SecretUri=$(TestDbConnSecretUri))"

    # ... Similar stages for UAT and Prod ...

    - stage: DeployProd
      displayName: 'Deploy to Production'
      dependsOn: Build # Or DeployUAT
      condition: succeeded() # Add manual approval for Prod
      variables:
      - group: MyFunctionApp-Prod-Vars
      jobs:
      - deployment: DeployFunctionAppProd
        environment: 'MyFunctionApp-Production' # This DevOps environment should have approvals configured
        strategy:
          runOnce:
            deploy:
              steps:
              - task: AzureFunctionApp@2
                displayName: 'Deploy Azure Function App to Prod'
                inputs:
                  azureSubscription: 'Your-Azure-Prod-Subscription-Service-Connection'
                  appType: 'functionApp'
                  appName: 'my-prod-functionapp-name'
                  package: '$(Pipeline.Workspace)/App/**/*.zip'
                  deploymentMethod: 'runFromPackage' # Recommended for prod
                  appSettings: >-
                    -AZURE_FUNCTIONS_ENVIRONMENT "Production"
                    -MyApplication:ServiceUrl "$(prodServiceUrl)"
                    -MyApplication:ApiKey "@Microsoft.KeyVault(SecretUri=$(ProdApiKeySecretUri))"
                    -EnvironmentSpecific:DatabaseConnectionString "@Microsoft.KeyVault(SecretUri=$(ProdDbConnSecretUri))"
    ```

    **Explanation of `appSettings` in YAML:**
    *   The `appSettings` parameter in the `AzureFunctionApp@2` task allows you to set or override Application Settings in your Azure Function App during deployment.
    *   `-SettingName "Value"`: For regular values.
    *   `-SettingName "@Microsoft.KeyVault(SecretUri=$(PipelineVariableContainingSecretUri))"`: For Key Vault references. The pipeline variable (e.g., `DevApiKeySecretUri`) would be defined in your Variable Group and linked to the Key Vault secret.
    *   You can use pipeline variables (e.g., `$(devServiceUrl)`) that are defined in the linked Variable Group.

    **Azure DevOps Environments & Approvals:**
    *   For UAT and Prod, configure "Environments" in Azure DevOps (Pipelines -> Environments).
    *   Add manual approval checks to these environments to ensure a human gate before deploying to critical stages.

**Summary of Best Practices:**

1.  **Consistent Configuration Model:** Use `Microsoft.Extensions.Configuration` across local and Azure.
2.  **Environment Identification:**
    *   Locally: `AZURE_FUNCTIONS_ENVIRONMENT` in `local.settings.json`.
    *   Azure: `AZURE_FUNCTIONS_ENVIRONMENT` as an App Setting in the Function App.
3.  **Configuration Files:**
    *   `appsettings.json` for defaults.
    *   `appsettings.{EnvironmentName}.json` for environment-specific non-sensitive overrides. Commit these.
4.  **Local Development Secrets:**
    *   User Secrets (preferred for sensitive items not directly related to Functions host).
    *   `local.settings.json` (ensure it's in `.gitignore` if it contains real secrets). Values here become environment variables locally.
5.  **Azure Secrets:** **Azure Key Vault** is non-negotiable. Use Key Vault references in Function App Settings.
6.  **Accessing Settings:** Use Dependency Injection with `IOptions<T>` for strongly-typed configuration.
7.  **Azure DevOps:**
    *   Use Variable Groups, linking to Key Vault for secrets for each environment.
    *   Use stage-specific deployments in your YAML pipeline.
    *   Set `AZURE_FUNCTIONS_ENVIRONMENT` and other Key Vault references/app settings via the `AzureFunctionApp@2` task's `appSettings` parameter.
    *   Alternatively, manage App Settings entirely via IaC (Bicep/ARM/Terraform) and only set `AZURE_FUNCTIONS_ENVIRONMENT` if it's dynamic per stage. However, Key Vault references often still need to be set on the App resource. The pipeline's `appSettings` allows dynamic updates.

This comprehensive approach provides a robust, secure, and maintainable way to manage configurations for your .NET 9 Azure Functions across all environments.

**Resources:**

*   **ASP.NET Core Configuration:** [https://docs.microsoft.com/en-us/aspnet/core/fundamentals/configuration/](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/configuration/) (Principles apply to isolated worker)
*   **Azure Functions - local.settings.json:** [https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-local#local-settings-file](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-local#local-settings-file)
*   **Dependency injection in .NET Azure Functions (isolated worker):** [https://docs.microsoft.com/en-us/azure/azure-functions/dotnet-isolated-process-guide#dependency-injection](https://docs.microsoft.com/en-us/azure/azure-functions/dotnet-isolated-process-guide#dependency-injection)
*   **Key Vault References for App Service and Azure Functions:** [https://docs.microsoft.com/en-us/azure/app-service/app-service-key-vault-references](https://docs.microsoft.com/en-us/azure/app-service/app-service-key-vault-references)
*   **Azure DevOps Variable Groups:** [https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups)
*   **AzureFunctionApp@2 Task:** [https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/azure-function-app](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/azure-function-app)
*   **User Secrets in .NET:** [https://docs.microsoft.com/en-us/aspnet/core/security/app-secrets](https://docs.microsoft.com/en-us/aspnet/core/security/app-secrets)
