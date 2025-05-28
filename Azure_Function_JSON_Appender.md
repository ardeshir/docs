# Azure Functions: JSON Appender

A .NET 9 (using C# 12 features) Azure Function with an isolated worker process (the recommended model) that triggers on a blob creation/update, converts JSON to YAML, and updates the original JSON.

**Assumptions:**

*   Your storage account is named `devsadatajson`.
*   The input `data.json` files will be placed in a container named `data-input`.
*   The generated YAML files will be placed in a container named `data-output`.
*   The original `data.json` in `data-input` will be updated in place.

**Prerequisites:**

1.  **.NET 9 SDK:** Ensure you have the .NET 9 SDK installed. ([https://dotnet.microsoft.com/download/dotnet/9.0](https://dotnet.microsoft.com/download/dotnet/9.0))
2.  **Azure Functions Core Tools:** Install or update to the latest version (v4).
    ```bash
    npm install -g azure-functions-core-tools@4 --unsafe-perm true
    # or if you prefer other installation methods:
    # https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local
    ```
3.  **Azure CLI:** Installed and logged in (`az login`).
4.  **An Azure Subscription:** To deploy resources.
5.  **Storage Account:** Create the `devsadatajson` storage account if it doesn't exist. You can do this via the Azure portal or Azure CLI:
    ```bash
    az group create --name <resource-group-name> --location <location>
    az storage account create --name devsadatajson --resource-group <resource-group-name> --location <location> --sku Standard_LRS
    ```
    You'll also need to create two containers within this storage account: `data-input` and `data-output`.
    ```bash
    # Get connection string for later (needed for local.settings.json and app settings)
    AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name devsadatajson --resource-group <resource-group-name> -o tsv)
    echo "Storage Connection String: $AZURE_STORAGE_CONNECTION_STRING" # Keep this handy

    az storage container create --name data-input --account-name devsadatajson --connection-string "$AZURE_STORAGE_CONNECTION_STRING"
    az storage container create --name data-output --account-name devsadatajson --connection-string "$AZURE_STORAGE_CONNECTION_STRING"
    ```

**Step 1: Create the Azure Functions Project**

1.  Open your terminal and navigate to where you want to create the project.
2.  Run the following command to create a new C# Azure Functions project targeting .NET 9 (isolated worker model):

    ```bash
    func init JsonToYamlFunctionProj --worker-runtime dotnet-isolated --target-framework net9.0
    cd JsonToYamlFunctionProj
    ```

3.  Create the function with a Blob Trigger:

    ```bash
    func new --name ProcessDataJson --template "Blob trigger" --language "C#"
    ```
    When prompted for the `setting name for the Azure Storage connection string`, you can enter `DevsaDataJsonConnection` (we'll define this later).
    For the `blob path`, enter `data-input/{name}.json`.

**Step 2: Update Project File and Add NuGet Packages**

1.  Open `JsonToYamlFunctionProj.csproj` and ensure it looks similar to this (adjusting for C# 12 if necessary, though `.NET 9` usually implies it):

    ```xml
    <Project Sdk="Microsoft.NET.Sdk">
      <PropertyGroup>
        <TargetFramework>net9.0</TargetFramework>
        <AzureFunctionsVersion>v4</AzureFunctionsVersion>
        <OutputType>Exe</OutputType>
        <ImplicitUsings>enable</ImplicitUsings>
        <Nullable>enable</Nullable>
        <!-- C# 12 Language Version (often default with .NET 8+, but explicit for clarity) -->
        <LangVersion>12.0</LangVersion>
      </PropertyGroup>
      <ItemGroup>
        <FrameworkReference Include="Microsoft.AspNetCore.App" /> <!-- Needed for ILogger in some cases -->
        <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.21.0" />
        <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Storage.Blobs" Version="6.3.0" />
        <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.0" />
        <PackageReference Include="Microsoft.ApplicationInsights.WorkerService" Version="2.22.0" />
        <PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="1.2.0" />
        <!-- Package for YAML processing -->
        <PackageReference Include="YamlDotNet" Version="15.1.2" />
        <!-- System.Text.Json is part of the .NET SDK but ensure you reference if specific features are needed outside core -->
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
    *   Make sure versions are up-to-date (`YamlDotNet`, `Microsoft.Azure.Functions.Worker.*`).
    *   `LangVersion` ensures C# 12 features are available.

2.  Restore packages:
    ```bash
    dotnet restore
    ```

**Step 3: Implement the Function Logic**

Open the generated `ProcessDataJson.cs` file and replace its content with the following:

```csharp
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes; // For JsonObject
using System.Threading.Tasks;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions; // For common naming conventions

namespace JsonToYamlFunctionProj
{
    public class ProcessDataJson
    {
        private readonly ILogger _logger;

        // Constructor injection for ILogger
        public ProcessDataJson(ILoggerFactory loggerFactory)
        {
            _logger = loggerFactory.CreateLogger<ProcessDataJson>();
        }

        [Function(nameof(ProcessDataJson))]
        // Output binding for the new YAML file
        // Note: The output blob path uses the '{name}' from the trigger, creating a corresponding YAML file.
        [BlobOutput("data-output/{name}.yaml", Connection = "DevsaDataJsonConnection")]
        public async Task<string> Run(
            [BlobTrigger("data-input/{name}.json", Connection = "DevsaDataJsonConnection")] Stream inputBlobStream,
            string name, // This is the blob name without the extension, extracted from the path
            Binder binder) // Binder allows us to bind to the input blob for writing
        {
            _logger.LogInformation($"C# Blob trigger function processing blob\n Name: {name}.json");

            string inputJsonContent;
            using (var reader = new StreamReader(inputBlobStream, Encoding.UTF8))
            {
                inputJsonContent = await reader.ReadToEndAsync();
            }

            if (string.IsNullOrWhiteSpace(inputJsonContent))
            {
                _logger.LogWarning($"Blob {name}.json is empty or whitespace. Skipping processing.");
                // Return null or empty for the YAML output to not create an empty YAML file.
                // Or throw an exception if this is an error condition.
                return "";
            }

            JsonObject? jsonObject;
            try
            {
                // Parse the JSON content into a JsonObject for easy manipulation
                var jsonNode = JsonNode.Parse(inputJsonContent);
                if (jsonNode is not JsonObject obj)
                {
                     _logger.LogError($"Content of {name}.json is not a JSON object. Found: {jsonNode?.GetType().Name}");
                     return $"Error: Content of {name}.json is not a JSON object."; // Return error string for YAML output
                }
                jsonObject = obj;
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, $"Error parsing JSON from {name}.json.");
                // Potentially write an error marker to the YAML output or handle differently
                return $"Error parsing JSON: {ex.Message}";
            }

            // 1. Convert JSON object to YAML string
            var serializer = new SerializerBuilder()
                .WithNamingConvention(CamelCaseNamingConvention.Instance) // Optional: for camelCase keys in YAML
                .Build();
            string yamlOutput = serializer.Serialize(jsonObject); // YamlDotNet can serialize JsonObject directly

            _logger.LogInformation($"Successfully converted {name}.json to YAML content.");

            // 2. Add/Update the 'updated' timestamp in the original JSON object
            // Using DateTimeOffset.UtcNow for better timezone handling and ISO 8601 format
            jsonObject["updated"] = DateTimeOffset.UtcNow.ToString("o"); // "o" is the round-trip format specifier

            var updatedJsonString = jsonObject.ToJsonString(new JsonSerializerOptions
            {
                WriteIndented = true // Make the updated JSON pretty
            });

            // 3. Save the updated JSON back to the original blob
            // We use Binder to get a writable stream to the original blob.
            var blobAttribute = new BlobAttribute($"data-input/{name}.json", FileAccess.Write)
            {
                Connection = "DevsaDataJsonConnection" // Specify the connection string setting name
            };

            try
            {
                using (var outputJsonStream = await binder.BindAsync<Stream>(blobAttribute))
                using (var writer = new StreamWriter(outputJsonStream, Encoding.UTF8))
                {
                    await writer.WriteAsync(updatedJsonString);
                }
                _logger.LogInformation($"Successfully updated {name}.json with timestamp.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Failed to update original blob {name}.json");
                // If updating the original fails, the YAML might still be created.
                // Decide on error handling strategy (e.g., delete YAML, log critical error)
                // For now, we let YAML be created and log the error.
            }


            // The 'return yamlOutput;' will be written to the BlobOutput defined in the method signature
            return yamlOutput;
        }
    }
}
```

**Explanation of `ProcessDataJson.cs`:**

*   **`ILogger`:** Injected for logging.
*   **`[Function(nameof(ProcessDataJson))]`:** Defines the function name.
*   **`[BlobTrigger("data-input/{name}.json", Connection = "DevsaDataJsonConnection")] Stream inputBlobStream, string name`:**
    *   Triggers when a blob is added/updated in the `data-input` container matching the pattern `*.json`.
    *   `{name}` is a binding expression that captures the filename without the extension.
    *   `Connection = "DevsaDataJsonConnection"` refers to a setting in `local.settings.json` (and later Azure App Settings) that holds the storage connection string.
    *   `Stream inputBlobStream`: Provides the content of the triggering blob as a stream.
*   **`[BlobOutput("data-output/{name}.yaml", Connection = "DevsaDataJsonConnection")]`:**
    *   This is an output binding. The string returned by the function will be written to a new blob.
    *   The path `data-output/{name}.yaml` means the YAML file will be created in the `data-output` container with the same base name as the input JSON file but with a `.yaml` extension.
*   **`Binder binder`:** This is a powerful parameter that allows you to imperatively bind to other Azure resources at runtime. We use it here to get a writable `Stream` to the *original* input blob path so we can update it.
*   **Reading Input:** The input blob stream is read into `inputJsonContent`.
*   **JSON Parsing:** `System.Text.Json.Nodes.JsonNode.Parse()` is used to parse the JSON into a `JsonObject`, which allows easy modification.
*   **YAML Conversion:**
    *   `YamlDotNet.Serialization.SerializerBuilder` is used to create a YAML serializer.
    *   `serializer.Serialize(jsonObject)` converts the `JsonObject` to a YAML string.
*   **Updating JSON:**
    *   `jsonObject["updated"] = DateTimeOffset.UtcNow.ToString("o");` adds/updates the `updated` field with the current UTC timestamp in ISO 8601 format.
    *   The modified `jsonObject` is serialized back to a string.
*   **Saving Updated JSON:**
    *   A `BlobAttribute` is created pointing to the original blob path (`data-input/{name}.json`) with `FileAccess.Write`.
    *   `binder.BindAsync<Stream>(blobAttribute)` obtains a writable stream to this blob.
    *   The `updatedJsonString` is written to this stream, effectively overwriting the original blob.
*   **Returning YAML:** The `yamlOutput` string is returned, and the Azure Functions runtime automatically writes this to the blob specified by the `BlobOutput` attribute.

**Step 4: Configure Local Settings**

Open `local.settings.json`. If it doesn't exist, create it in the root of `JsonToYamlFunctionProj`.
Update it like this:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true", // Or your actual Azure Storage connection string for function operational data
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "DevsaDataJsonConnection": "YOUR_DEVSADATAJSON_STORAGE_ACCOUNT_CONNECTION_STRING" // Replace with the actual connection string
  }
}
```

*   **`AzureWebJobsStorage`**: Connection string for the storage account Azure Functions uses for its own operational needs (e.g., triggers, logs). For local development, `UseDevelopmentStorage=true` works if you have the Azure Storage Emulator running. Otherwise, use a real Azure Storage connection string.
*   **`DevsaDataJsonConnection`**: **Crucially, replace `YOUR_DEVSADATAJSON_STORAGE_ACCOUNT_CONNECTION_STRING` with the actual connection string for your `devsadatajson` storage account that you obtained in the prerequisites.**

**Step 5: Test Locally**

1.  Start the function host:
    ```bash
    func start
    ```
    You should see output indicating the function host has started and your `ProcessDataJson` function is loaded.

2.  **Trigger the function:**
    *   Use Azure Storage Explorer or the Azure CLI to upload a sample `data.json` file into the `data-input` container of your `devsadatajson` storage account.

    Example `data.json`:
    ```json
    {
      "id": "123",
      "name": "Sample Item",
      "details": {
        "color": "blue",
        "size": "large"
      },
      "tags": [ "test", "sample" ]
    }
    ```

3.  **Observe:**
    *   **Console Output:** You should see log messages from your function in the `func start` console.
    *   **`data-output` container:** A new file (e.g., `data.yaml`) should appear with the YAML content.
        Example `data.yaml`:
        ```yaml
        id: 123
        name: Sample Item
        details:
          color: blue
          size: large
        tags:
        - test
        - sample
        # The 'updated' field might also appear here if YamlDotNet serializes it
        # before it was added in the JSON object for the original file update step.
        # This depends on the exact object state passed to YamlDotNet.
        # If you want 'updated' ONLY in the JSON, serialize to YAML *before* adding the timestamp.
        # Our current code serializes `jsonObject` which at that point doesn't have "updated" yet.
        # Then it adds "updated" to `jsonObject` and saves that. So YAML should be clean.
        ```
    *   **`data-input` container:** The original `data.json` file should be updated to include the `updated` field:
        ```json
        {
          "id": "123",
          "name": "Sample Item",
          "details": {
            "color": "blue",
            "size": "large"
          },
          "tags": [
            "test",
            "sample"
          ],
          "updated": "YYYY-MM-DDTHH:mm:ss.fffffffZ" // Actual ISO 8601 timestamp
        }
        ```

**Step 6: Deploy to Azure**

1.  **Login to Azure (if not already):**
    ```bash
    az login
    ```

2.  **Create Azure Resources (Function App, supporting Storage, App Insights):**
    You'll need a Resource Group, a Storage Account (different from `devsadatajson`, this one is for the Function App's operational needs), and a Function App.

    ```bash
    # Variables (customize these)
    RESOURCE_GROUP="MyFunctionAppRG"
    LOCATION="EastUS" # Choose a region
    FUNCTION_APP_STORAGE_NAME="funcstor$(openssl rand -hex 4)" # Unique name for function's storage
    FUNCTION_APP_NAME="jsonyamlprocfunc-$(openssl rand -hex 4)" # Unique name for your function app

    # Create Resource Group
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

    # Create Storage Account for Function App
    az storage account create \
      --name "$FUNCTION_APP_STORAGE_NAME" \
      --location "$LOCATION" \
      --resource-group "$RESOURCE_GROUP" \
      --sku Standard_LRS

    # Create Function App
    # For .NET 9 Isolated, you need to specify --runtime dotnet-isolated and --os-type (Linux is common)
    # Also, ensure --functions-version is 4
    az functionapp create \
      --resource-group "$RESOURCE_GROUP" \
      --consumption-plan-location "$LOCATION" \
      --runtime dotnet-isolated \
      --runtime-version 9.0 \
      --functions-version 4 \
      --name "$FUNCTION_APP_NAME" \
      --os-type Linux \
      --storage-account "$FUNCTION_APP_STORAGE_NAME"
    ```
    *Note: `--runtime-version 9.0` might need to be adjusted if the specific naming scheme for .NET 9 in Azure Functions provisioning changes. Check `az functionapp list-runtimes` for exact values if you encounter issues.*

3.  **Configure Application Settings in Azure:**
    The deployed Function App needs the `DevsaDataJsonConnection` string.
    ```bash
    # Get the connection string for devsadatajson (if you don't have it handy)
    DEVSADATAJSON_CONNECTION_STRING=$(az storage account show-connection-string --name devsadatajson --resource-group <your-rg-for-devsadatajson> -o tsv)

    az functionapp config appsettings set \
      --name "$FUNCTION_APP_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --settings "DevsaDataJsonConnection=$DEVSADATAJSON_CONNECTION_STRING" \
                 "FUNCTIONS_EXTENSION_VERSION=~4" # Ensure v4 functions runtime
    ```
    The `AzureWebJobsStorage` setting is usually configured automatically during Function App creation to point to `$FUNCTION_APP_STORAGE_NAME`.

4.  **Deploy the Function Code:**
    Navigate back to your `JsonToYamlFunctionProj` directory in the terminal.
    ```bash
    # Build in release configuration (optional but good practice)
    dotnet build --configuration Release

    # Publish using Azure Functions Core Tools
    func azure functionapp publish "$FUNCTION_APP_NAME" --dotnet-isolated # Add --nozip for Linux Consumption plan if needed sometimes
    ```
    Alternatively, for zip deploy (often preferred):
    ```bash
    # If you built with Release config:
    func azure functionapp publish "$FUNCTION_APP_NAME" --zip-deploy --no-build -p ./bin/Release/net9.0/publish
    # If you didn't specify Release build earlier, or want func tools to handle build:
    # func azure functionapp publish "$FUNCTION_APP_NAME" --zip-deploy
    ```

**Step 7: Test in Azure**

1.  Go to the Azure portal, find your `devsadatajson` storage account.
2.  Navigate to the `data-input` container.
3.  Upload a `data.json` file.
4.  Monitor the Function App's "Monitor" or "Log stream" section in the Azure portal to see execution logs.
5.  Check the `data-output` container for the generated `.yaml` file and the `data-input` container to see if the original `.json` file was updated with the timestamp.

This comprehensive guide should help you build, test, and deploy your C# Azure Function for processing JSON files. Remember to replace placeholders with your actual resource names and connection strings.
