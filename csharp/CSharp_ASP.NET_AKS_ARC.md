## Containerized HTTP API on AKS deployed via Azure DevOps

Let's break this down into phases:

**Phase 1: Convert CLI to ASP.NET Core Web API**
**Phase 2: Integrate Azure Blob Storage for Markdown Output**
**Phase 3: Dockerize the Application**
**Phase 4: Set up Azure Kubernetes Service (AKS) and Azure Container Registry (ACR)**
**Phase 5: Create Azure DevOps Pipelines for CI/CD**

---

**Pre-requisites:**

*   Azure Subscription
*   Azure CLI installed and configured
*   Docker Desktop installed
*   .NET 9 SDK (already installed from previous steps)
*   An Azure DevOps organization and project

---

**Phase 1: Convert CLI to ASP.NET Core Web API**

1.  **Create a New Web API Project (or modify existing):**
    It's often cleaner to create a new Web API project and move the core logic (services, models) into it or shared class libraries. Let's assume we're creating a new one and will reference the core logic.

    ```bash
    # Navigate to your solutions directory (parent of JsonToMarkdownAppender)
    cd ..
    dotnet new webapi -n MarkdownApiService -f net9.0
    cd MarkdownApiService
    ```

2.  **Reference Core Logic (if separated):**
    If your `Core`, `Models`, and `Services` (like `JsonContent`, `IMarkdownConverter`, `SimpleMarkdownConverter`) are in the `JsonToMarkdownAppender` project or a separate class library, you'll need to reference them.
    For simplicity, let's assume we'll copy/recreate necessary classes directly in the `MarkdownApiService` project for now, or adjust namespaces if moving files.

    *   Copy/move `Models/JsonContent.cs`.
    *   Copy/move `Core/IMarkdownConverter.cs`.
    *   Copy/move `Services/SimpleMarkdownConverter.cs`.
    *   The `IJsonProcessor` isn't strictly needed if the JSON comes directly in the POST body, as ASP.NET Core handles deserialization.
    *   `IFileFinder`, `IFileArchiver` (for local files), and `AppLogic` will be significantly changed or replaced by API-specific logic and Azure Blob Storage interaction.

3.  **Update `Models/JsonContent.cs` (if not already done):**
    Ensure it matches the structure from your last update:
    ```csharp
    // Models/JsonContent.cs
    namespace MarkdownApiService.Models; // Adjust namespace

    public class JsonContent
    {
        public string? Title { get; set; }
        public string? Description { get; set; }
        public string? Date { get; set; }
        public string? Version { get; set; }
        public string? Status { get; set; }
        public string? Author { get; set; }
        public List<string>? Content { get; set; }
        public List<string>? Tags { get; set; }
    }
    ```

4.  **Update `Services/SimpleMarkdownConverter.cs`:**
    Adjust namespace if necessary. The implementation can remain the same.
    ```csharp
    // Services/SimpleMarkdownConverter.cs
    namespace MarkdownApiService.Services; // Adjust namespace
    // ... (rest of the class) ...
    ```
    Ensure `Core/IMarkdownConverter.cs` also has the correct namespace.

5.  **Create an API Controller:**
    Create `Controllers/ParserController.cs`:
    ```csharp
    // Controllers/ParserController.cs
    using Microsoft.AspNetCore.Mvc;
    using MarkdownApiService.Models;
    using MarkdownApiService.Services; // For IMarkdownConverter
    // Add using for Azure Blob Service later
    using System.Threading.Tasks;

    namespace MarkdownApiService.Controllers;

    [ApiController]
    [Route("api/[controller]")]
    public class ParserController : ControllerBase
    {
        private readonly IMarkdownConverter<JsonContent> _markdownConverter;
        // Inject IAzureBlobStorageService later

        public ParserController(IMarkdownConverter<JsonContent> markdownConverter /*, IAzureBlobStorageService blobService */)
        {
            _markdownConverter = markdownConverter;
            // _blobService = blobService;
        }

        [HttpPost]
        public async Task<IActionResult> ParseAndStore([FromBody] JsonContent jsonData,
                                                     [FromQuery] string targetBlobName = "defaultOutput.md",
                                                     [FromQuery] bool append = true)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            if (jsonData == null)
            {
                return BadRequest("JSON data is required in the request body.");
            }

            // 1. Convert JSON to Markdown (using existing service)
            string newMarkdownContent = _markdownConverter.Convert(jsonData);

            if (string.IsNullOrEmpty(newMarkdownContent) && !append)
            {
                 // If replacing and new content is empty, we might still want to proceed to "empty" the blob
                 // For now, let's treat this as a success with no content.
                 Console.WriteLine("Generated Markdown is empty. Target will be updated with empty content if in replace mode.");
            }
            else if (string.IsNullOrEmpty(newMarkdownContent)) {
                 Console.WriteLine("Generated Markdown is empty. Nothing to append.");
                 return Ok("Generated Markdown was empty, no changes made to blob storage.");
            }


            // 2. Logic to interact with Azure Blob Storage (Phase 2)
            // For now, let's just return the markdown
            // string finalContentForBlob = newMarkdownContent;
            // if (append) { /* Logic to get existing blob, append, etc. */ }
            // await _blobService.UploadMarkdownAsync(targetBlobName, finalContentForBlob, append);

            return Ok(new { message = "JSON parsed. Markdown generated (Azure Blob Storage integration pending).", markdown = newMarkdownContent, targetBlob = targetBlobName, appendMode = append });
        }
    }
    ```

6.  **Configure Services in `Program.cs`:**
    ```csharp
    // Program.cs (MarkdownApiService project)
    using MarkdownApiService.Models;
    using MarkdownApiService.Services; // For IMarkdownConverter & SimpleMarkdownConverter
    // Add using for Core interfaces if they are in a different namespace
    // using JsonToMarkdownAppender.Core; // Example if interfaces are kept in old project's namespace

    var builder = WebApplication.CreateBuilder(args);

    // Add services to the container.
    builder.Services.AddControllers();
    // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen();

    // Register your custom services
    builder.Services.AddSingleton<IMarkdownConverter<JsonContent>, SimpleMarkdownConverter>();
    // Add Azure Blob Storage service registration later

    var app = builder.Build();

    // Configure the HTTP request pipeline.
    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI();
    }

    app.UseHttpsRedirection(); // Recommended for production
    app.UseAuthorization();
    app.MapControllers();

    app.Run();
    ```

7.  **Test Locally (Phase 1 completion):**
    *   Run the API: `dotnet run` from the `MarkdownApiService` directory.
    *   Open your browser to `https://localhost:<port>/swagger` (or `http://localhost:<port>/swagger`).
    *   Use Swagger UI to test the `POST /api/parser` endpoint. Provide a JSON body like your `data.json` and try different `targetBlobName` and `append` query parameters.
    *   You should get the generated Markdown back in the response for now.

---

**Phase 2: Integrate Azure Blob Storage for Markdown Output**

1.  **Add NuGet Package for Azure Blob Storage:**
    ```bash
    dotnet add package Azure.Storage.Blobs
    ```

2.  **Add Configuration for Blob Storage:**
    In `appsettings.json` (and `appsettings.Development.json` for local dev):
    ```json
    // appsettings.json
    {
      "Logging": { /* ... */ },
      "AllowedHosts": "*",
      "AzureBlobStorage": {
        "ConnectionString": "YOUR_AZURE_STORAGE_CONNECTION_STRING", // Use User Secrets or Key Vault for real connection strings
        "ContainerName": "markdown-outputs" // Or your preferred container name
      }
    }
    ```
    **IMPORTANT for Production:** Do NOT commit actual connection strings to source control. Use:
    *   **User Secrets** for local development: `dotnet user-secrets init`, `dotnet user-secrets set "AzureBlobStorage:ConnectionString" "your_connection_string"`
    *   **Azure Key Vault** and Managed Identities for Azure deployments (AKS).

3.  **Create an Azure Blob Storage Service Interface and Implementation:**
    `Services/IAzureBlobStorageService.cs`:
    ```csharp
    namespace MarkdownApiService.Services;

    public interface IAzureBlobStorageService
    {
        Task UploadMarkdownAsync(string blobName, string content, bool append);
        Task ArchiveBlobAsync(string sourceBlobName, string archiveBlobName); // Optional for archiving
    }
    ```
    `Services/AzureBlobStorageService.cs`:
    ```csharp
    using Azure.Storage.Blobs;
    using Azure.Storage.Blobs.Models;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.Logging; // For logging
    using System;
    using System.IO;
    using System.Text;
    using System.Threading.Tasks;

    namespace MarkdownApiService.Services;

    public class AzureBlobStorageService : IAzureBlobStorageService
    {
        private readonly BlobContainerClient _containerClient;
        private readonly ILogger<AzureBlobStorageService> _logger;

        public AzureBlobStorageService(IConfiguration configuration, ILogger<AzureBlobStorageService> logger)
        {
            _logger = logger;
            var connectionString = configuration["AzureBlobStorage:ConnectionString"];
            var containerName = configuration["AzureBlobStorage:ContainerName"];

            if (string.IsNullOrEmpty(connectionString) || string.IsNullOrEmpty(containerName))
            {
                _logger.LogError("Azure Blob Storage connection string or container name is not configured.");
                // Throw an exception or handle appropriately for your application's startup.
                // For DI to work, the service needs to be constructible.
                // This check is more for runtime, but illustrates the need for config.
                throw new InvalidOperationException("Azure Blob Storage not configured properly.");
            }

            try
            {
                var blobServiceClient = new BlobServiceClient(connectionString);
                _containerClient = blobServiceClient.GetBlobContainerClient(containerName);
                _containerClient.CreateIfNotExistsAsync(PublicAccessType.None).GetAwaiter().GetResult(); // Ensure container exists
                 _logger.LogInformation($"Successfully connected to Azure Blob Storage container: {containerName}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to initialize Azure Blob Storage client or ensure container exists.");
                throw; // Re-throw to prevent application from starting in a bad state
            }
        }

        public async Task UploadMarkdownAsync(string blobName, string newContent, bool append)
        {
            BlobClient blobClient = _containerClient.GetBlobClient(blobName);
            string finalContent = newContent;

            if (append)
            {
                string existingContent = "";
                if (await blobClient.ExistsAsync())
                {
                    _logger.LogInformation($"Blob '{blobName}' exists. Attempting to read for append.");
                    try
                    {
                        BlobDownloadInfo download = await blobClient.DownloadAsync();
                        using var reader = new StreamReader(download.Content);
                        existingContent = await reader.ReadToEndAsync();

                        if (!string.IsNullOrEmpty(existingContent) &&
                            !existingContent.EndsWith(Environment.NewLine + Environment.NewLine) && // Ensure good spacing
                            !existingContent.EndsWith("\n\n"))
                        {
                             if (!existingContent.EndsWith(Environment.NewLine) && !existingContent.EndsWith("\n"))
                             {
                                existingContent += Environment.NewLine; // Add one if none
                             }
                             existingContent += Environment.NewLine; // Add another for a blank line before new content
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, $"Failed to read existing content from blob '{blobName}' for append. Will overwrite or create new.");
                        // Decide behavior: overwrite, or fail? For now, let's effectively overwrite if read fails.
                        existingContent = "";
                    }
                }
                else
                {
                    _logger.LogInformation($"Blob '{blobName}' does not exist. Will create new for append operation.");
                }
                finalContent = existingContent + newContent;
            }
            else
            {
                 _logger.LogInformation($"Replace mode for blob '{blobName}'. Archiving previous version if it exists.");
                 // Optional: Archive before replacing
                 if (await blobClient.ExistsAsync())
                 {
                    string archiveBlobName = $"{Path.GetFileNameWithoutExtension(blobName)}_{DateTime.UtcNow:yyyyMMddHHmmssfff}{Path.GetExtension(blobName)}";
                    // Consider putting archives in a subfolder e.g., "archive/" + archiveBlobName
                    await ArchiveBlobAsync(blobName, "archive/" + archiveBlobName);
                 }
            }

            using var memoryStream = new MemoryStream(Encoding.UTF8.GetBytes(finalContent));
            await blobClient.UploadAsync(memoryStream, overwrite: true); // Overwrite with new/appended content
            _logger.LogInformation($"Successfully uploaded/updated blob: {blobName}");
        }

        public async Task ArchiveBlobAsync(string sourceBlobName, string archiveBlobName)
        {
            BlobClient sourceBlobClient = _containerClient.GetBlobClient(sourceBlobName);
            BlobClient archiveBlobClient = _containerClient.GetBlobClient(archiveBlobName);

            if (!await sourceBlobClient.ExistsAsync())
            {
                _logger.LogWarning($"Source blob '{sourceBlobName}' not found for archiving.");
                return;
            }

            try
            {
                await archiveBlobClient.StartCopyFromUriAsync(sourceBlobClient.Uri);
                // Wait for copy to complete - simple poll or use event grid for production
                BlobProperties props = await archiveBlobClient.GetPropertiesAsync();
                while(props.BlobCopyStatus == CopyStatus.Pending) {
                    await Task.Delay(500); // Poll every 0.5 seconds
                    props = await archiveBlobClient.GetPropertiesAsync();
                }

                if(props.BlobCopyStatus == CopyStatus.Success)
                {
                    _logger.LogInformation($"Successfully archived '{sourceBlobName}' to '{archiveBlobName}'.");
                    // Optionally delete the source after archiving if it's a move operation,
                    // but for replace, we are overwriting the source, so this step might be part of a different flow.
                    // For this "replace" scenario, archiving means making a copy *before* overwrite.
                } else {
                     _logger.LogError($"Failed to archive '{sourceBlobName}' to '{archiveBlobName}'. Copy status: {props.BlobCopyStatus}, Description: {props.CopyStatusDescription}");
                }

            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error archiving blob '{sourceBlobName}' to '{archiveBlobName}'.");
            }
        }
    }
    ```

4.  **Register `IAzureBlobStorageService` in `Program.cs`:**
    ```csharp
    // Program.cs
    // ... other usings ...
    using MarkdownApiService.Services;

    // ...
    builder.Services.AddSingleton<IMarkdownConverter<JsonContent>, SimpleMarkdownConverter>();
    builder.Services.AddSingleton<IAzureBlobStorageService, AzureBlobStorageService>(); // Add this
    // ...
    ```

5.  **Update `ParserController.cs` to use the Blob Service:**
    ```csharp
    // Controllers/ParserController.cs
    using Microsoft.AspNetCore.Mvc;
    using MarkdownApiService.Models;
    using MarkdownApiService.Services;
    using System.Threading.Tasks;
    using Microsoft.Extensions.Logging; // For logging

    namespace MarkdownApiService.Controllers;

    [ApiController]
    [Route("api/[controller]")]
    public class ParserController : ControllerBase
    {
        private readonly IMarkdownConverter<JsonContent> _markdownConverter;
        private readonly IAzureBlobStorageService _blobService;
        private readonly ILogger<ParserController> _logger;

        public ParserController(
            IMarkdownConverter<JsonContent> markdownConverter,
            IAzureBlobStorageService blobService,
            ILogger<ParserController> logger) // Inject logger
        {
            _markdownConverter = markdownConverter;
            _blobService = blobService;
            _logger = logger;
        }

        [HttpPost]
        public async Task<IActionResult> ParseAndStore([FromBody] JsonContent jsonData,
                                                     [FromQuery] string targetBlobName = "defaultOutput.md",
                                                     [FromQuery] bool append = true) // Default to append
        {
            if (!ModelState.IsValid)
            {
                _logger.LogWarning("Invalid model state received.");
                return BadRequest(ModelState);
            }
            if (jsonData == null)
            {
                _logger.LogWarning("Null JSON data received in POST request.");
                return BadRequest("JSON data is required in the request body.");
            }

            _logger.LogInformation($"Received request to parse and store. TargetBlob: {targetBlobName}, AppendMode: {append}");

            string newMarkdownContent = _markdownConverter.Convert(jsonData);

            if (string.IsNullOrEmpty(newMarkdownContent) && append)
            {
                 _logger.LogInformation("Generated Markdown was empty, and in append mode. No changes will be made to blob storage.");
                 return Ok(new { message = "Generated Markdown was empty, no changes made to blob storage.", targetBlob = targetBlobName });
            }
             if (string.IsNullOrEmpty(newMarkdownContent) && !append)
            {
                 _logger.LogInformation("Generated Markdown was empty, and in replace mode. Blob will be updated with empty content.");
                 // Allow empty content to be written in replace mode to clear a blob
            }


            try
            {
                await _blobService.UploadMarkdownAsync(targetBlobName, newMarkdownContent, append);
                _logger.LogInformation($"Successfully processed and uploaded to blob: {targetBlobName}");
                return Ok(new { message = $"Markdown {(append ? "appended to" : "replaced in")} blob '{targetBlobName}'.", targetBlob = targetBlobName });
            }
            catch (System.Exception ex)
            {
                _logger.LogError(ex, $"Error during blob upload operation for '{targetBlobName}'.");
                return StatusCode(500, "An error occurred while processing your request and interacting with blob storage.");
            }
        }
    }
    ```

6.  **Create an Azure Storage Account and Container:**
    *   Use Azure Portal or Azure CLI:
        ```bash
        # Variables
        RESOURCE_GROUP="YourResourceGroupName" # Create if not exists
        STORAGE_ACCOUNT_NAME="youruniquestorageaccname" # Must be globally unique
        LOCATION="eastus" # Or your preferred region
        CONTAINER_NAME="markdown-outputs" # Matches appsettings.json

        # Create Resource Group (if needed)
        az group create --name $RESOURCE_GROUP --location $LOCATION

        # Create Storage Account
        az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --sku Standard_LRS --kind StorageV2

        # Get Connection String (for local testing - copy this to user secrets)
        az storage account show-connection-string --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP -o tsv

        # Create Container
        az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --auth-mode login # or use --connection-string
        ```
    *   Update your user secrets with the actual connection string.

7.  **Test Locally (Phase 2 completion):**
    *   Run `dotnet run`.
    *   Use Swagger or Postman to send a POST request to `/api/parser`.
    *   Verify that the Markdown file appears/updates in your Azure Blob Storage container. Check append vs. replace logic and archiving.

---

**Phase 3: Dockerize the Application**

1.  **Create a `Dockerfile` in the `MarkdownApiService` project root:**
    ```dockerfile
    # Stage 1: Build the application
    FROM mcr.microsoft.com/dotnet/sdk:9.0-preview AS build
    WORKDIR /src

    # Copy csproj and restore as distinct layers to leverage Docker cache
    COPY ["MarkdownApiService.csproj", "./"]
    RUN dotnet restore "./MarkdownApiService.csproj"

    # Copy everything else and build
    COPY . .
    WORKDIR "/src/."
    RUN dotnet build "MarkdownApiService.csproj" -c Release -o /app/build

    # Stage 2: Publish the application
    FROM build AS publish
    RUN dotnet publish "MarkdownApiService.csproj" -c Release -o /app/publish /p:UseAppHost=false

    # Stage 3: Create the final runtime image
    FROM mcr.microsoft.com/dotnet/aspnet:9.0-preview AS final
    WORKDIR /app
    COPY --from=publish /app/publish .

    # Expose port (ensure this matches Kestrel configuration if not default 80/443)
    # ASP.NET Core apps default to port 8080 (HTTP) and 8081 (HTTPS) when run in containers from .NET 8+ SDK images
    # Or port 80 (HTTP) / 443 (HTTPS) for older images / explicit config
    # Let's assume Kestrel will listen on 8080 internally in the container.
    # If you have UseHttpsRedirection(), you'll need certs in container or terminate SSL at ingress.
    ENV ASPNETCORE_URLS=http://+:8080
    EXPOSE 8080

    ENTRYPOINT ["dotnet", "MarkdownApiService.dll"]
    ```
    *Note on .NET 9 and ports: The default port for ASP.NET Core apps in containers built with .NET 8+ SDK images is 8080 (HTTP) and 8081 (HTTPS). The `ASPNETCORE_URLS=http://+:8080` line makes it explicit. If you use `UseHttpsRedirection()` and want HTTPS within the container, certificate management is needed. Usually, SSL termination is handled by an ingress controller in Kubernetes.*

2.  **Create a `.dockerignore` file:**
    ```
    **/.classpath
    **/.dockerignore
    **/.env
    **/.git
    **/.gitignore
    **/.project
    **/.settings
    **/.toolstarget
    **/.vs
    **/.vscode
    **/*.*proj.user
    **/*.dbmdl
    **/*.jfm
    **/azds.yaml
    **/bin
    **/charts
    **/docker-compose*
    **/Dockerfile*
    **/node_modules
    **/npm-debug.log
    **/obj
    **/secrets.dev.yaml
    **/values.dev.yaml
    LICENSE
    README.md
    ```

3.  **Build and Run the Docker Image Locally:**
    ```bash
    # Build the image
    docker build -t markdown-api-service .

    # Run the container (map container port 8080 to host port e.g. 8088)
    # Pass the connection string as an environment variable for testing
    # Replace with your actual connection string for testing
    docker run -d -p 8088:8080 \
      -e "AzureBlobStorage__ConnectionString=YOUR_ACTUAL_CONNECTION_STRING_FOR_TESTING" \
      -e "AzureBlobStorage__ContainerName=markdown-outputs" \
      --name markdown-api-runner markdown-api-service
    ```
    *   Test by accessing `http://localhost:8088/api/parser` (or `/swagger`) via Postman/browser.
    *   Remember to stop and remove the container: `docker stop markdown-api-runner && docker rm markdown-api-runner`.

---

**Phase 4: Set up Azure Kubernetes Service (AKS) and Azure Container Registry (ACR)**

1.  **Create Azure Container Registry (ACR):**
    ```bash
    ACR_NAME="youruniqueacrname" # Must be globally unique
    az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true # Admin for simplicity, service principal for prod
    ```

2.  **Login to ACR (from where you'll push the Docker image, e.g., local machine or CI agent):**
    ```bash
    az acr login --name $ACR_NAME
    ```

3.  **Tag and Push your Docker Image to ACR:**
    ```bash
    docker tag markdown-api-service $ACR_NAME.azurecr.io/markdown-api-service:v1.0.0
    docker push $ACR_NAME.azurecr.io/markdown-api-service:v1.0.0
    ```

4.  **Create Azure Kubernetes Service (AKS) Cluster:**
    ```bash
    AKS_CLUSTER_NAME="markdownApiServiceCluster"
    # For production, consider more nodes, larger VM sizes, and enabling features like Azure CNI, monitoring, etc.
    az aks create --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME \
      --node-count 1 \
      --enable-addons monitoring \
      --generate-ssh-keys \
      --attach-acr $ACR_NAME # This grants AKS pull rights from ACR
    ```
    This can take 10-15 minutes.

5.  **Get AKS Credentials:**
    ```bash
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --overwrite-existing
    kubectl config current-context # Verify context is set to your new AKS cluster
    ```

6.  **Create Kubernetes Manifests:**
    Create a folder `k8s` in your `MarkdownApiService` project.

    `k8s/secret.yaml` (template - **DO NOT COMMIT ACTUAL SECRETS**):
    You'll create this manually in the cluster or via a secure pipeline step.
    The connection string needs to be base64 encoded.
    `echo -n "YOUR_AZURE_STORAGE_CONNECTION_STRING" | base64`
    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: azure-storage-secret
    type: Opaque
    data:
      connectionstring: YOUR_BASE64_ENCODED_CONNECTION_STRING
    ```

    `k8s/deployment.yaml`:
    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: markdown-api-deployment
    spec:
      replicas: 2 # Start with 2 replicas
      selector:
        matchLabels:
          app: markdown-api
      template:
        metadata:
          labels:
            app: markdown-api
        spec:
          containers:
          - name: markdown-api-service
            image: youruniqueacrname.azurecr.io/markdown-api-service:v1.0.0 # Replace with your ACR name and tag
            ports:
            - containerPort: 8080 # Matches EXPOSE and ASPNETCORE_URLS in Dockerfile
            env:
            - name: AzureBlobStorage__ContainerName
              value: "markdown-outputs"
            - name: AzureBlobStorage__ConnectionString
              valueFrom:
                secretKeyRef:
                  name: azure-storage-secret # Name of the k8s secret
                  key: connectionstring    # Key within the secret
            # Liveness and Readiness Probes are highly recommended for production
            livenessProbe:
              httpGet:
                path: /healthz # Implement a health check endpoint
                port: 8080
              initialDelaySeconds: 15
              periodSeconds: 20
            readinessProbe:
              httpGet:
                path: /readyz # Implement a readiness endpoint
                port: 8080
              initialDelaySeconds: 5
              periodSeconds: 10
    ```
    *You'll need to add `/healthz` and `/readyz` endpoints to your API. ASP.NET Core provides Health Checks middleware for this.*

    `k8s/service.yaml`:
    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: markdown-api-service-lb
    spec:
      type: LoadBalancer # Exposes the service externally with an Azure Load Balancer
      ports:
      - port: 80 # External port
        targetPort: 8080 # Container port
      selector:
        app: markdown-api # Matches labels in Deployment
    ```

7.  **Implement Health Check Endpoints (Optional but Recommended):**
    In `Program.cs`:
    ```csharp
    // ...
    builder.Services.AddHealthChecks(); // Add this

    var app = builder.Build();
    // ...
    app.MapHealthChecks("/healthz"); // Simple health check
    app.MapHealthChecks("/readyz");  // Can add more sophisticated checks
    app.MapControllers();
    app.Run();
    ```

8.  **Deploy to AKS:**
    *   **First, create the secret securely:**
        Get your base64 encoded connection string: `echo -n "DefaultEndpointsProtocol=..." | base64`
        Update `k8s/secret.yaml` with this value (or a placeholder if generating dynamically).
        ```bash
        kubectl apply -f k8s/secret.yaml # Create manually or via pipeline
        ```
    *   **Deploy the application:**
        ```bash
        kubectl apply -f k8s/deployment.yaml
        kubectl apply -f k8s/service.yaml
        ```
    *   **Check deployment status:**
        ```bash
        kubectl get deployments
        kubectl get pods
        kubectl get service markdown-api-service-lb -o wide # Wait for EXTERNAL-IP
        ```
    *   Once you have the `EXTERNAL-IP`, you can test: `http://<EXTERNAL-IP>/api/parser`

---

**Phase 5: Create Azure DevOps Pipelines for CI/CD**

1.  **Prepare Azure DevOps:**
    *   Ensure your code is in an Azure Repos Git repository.
    *   Create a Service Connection in Azure DevOps Project Settings:
        *   **Azure Resource Manager:** To interact with Azure (ACR, AKS). Use Service Principal authentication. Grant this Service Principal "AcrPush" role on ACR and "Contributor" or a custom role with necessary permissions on AKS cluster/resource group.
        *   **Docker Registry:** To connect to your ACR. Select "Azure Container Registry", choose your subscription and ACR instance.

2.  **Create `azure-pipelines.yml` (CI - Build and Push Docker Image):**
    Place this file in the root of your `MarkdownApiService` repository.
    ```yaml
    trigger:
    - main # Or your main branch

    pool:
      vmImage: 'ubuntu-latest'

    variables:
      BuildConfiguration: 'Release'
      DockerRegistryServiceConnection: 'YourACRServiceConnectionName' # Name of your Docker Registry service connection
      ImageRepository: 'markdown-api-service' # Name of the image in ACR
      AcrName: 'youruniqueacrname' # Your ACR name (without .azurecr.io)
      TagName: '$(Build.BuildId)' # Use BuildId for unique tags
      K8sManifestPath: '$(Build.SourcesDirectory)/k8s'

    stages:
    - stage: Build
      displayName: 'Build and Push Docker Image'
      jobs:
      - job: BuildAndPush
        displayName: 'Build, Test, and Push'
        steps:
        - task: UseDotNet@2
          displayName: 'Use .NET 9 SDK Preview'
          inputs:
            packageType: 'sdk'
            version: '9.0.x' # Or be more specific if a particular preview is needed
            performMultiLevelLookup: true
            includePreviewVersions: true

        - task: DotNetCoreCLI@2
          displayName: 'Restore NuGet Packages'
          inputs:
            command: 'restore'
            projects: '**/*.csproj'
            feedsToUse: 'select'

        - task: DotNetCoreCLI@2
          displayName: 'Build Application'
          inputs:
            command: 'build'
            projects: '**/*.csproj'
            arguments: '--configuration $(BuildConfiguration)'

        # Add Unit Test task here if you have tests
        # - task: DotNetCoreCLI@2
        #   displayName: 'Run Unit Tests'
        #   inputs:
        #     command: 'test'
        #     projects: '**/*Tests/*.csproj' # Adjust path to your test project
        #     arguments: '--configuration $(BuildConfiguration)'

        - task: DotNetCoreCLI@2
          displayName: 'Publish Application'
          inputs:
            command: 'publish'
            publishWebProjects: true # if it's a web project
            projects: '**/MarkdownApiService.csproj' # Adjust if csproj name is different
            arguments: '--configuration $(BuildConfiguration) --output $(Build.ArtifactStagingDirectory)/publish'
            zipAfterPublish: false

        - task: Docker@2
          displayName: 'Build and Push Docker Image to ACR'
          inputs:
            command: 'buildAndPush'
            repository: '$(ImageRepository)'
            dockerfile: '$(Build.SourcesDirectory)/Dockerfile' # Path to your Dockerfile
            containerRegistry: '$(DockerRegistryServiceConnection)'
            tags: |
              $(TagName)
              latest
            buildContext: '$(Build.SourcesDirectory)' # Set build context to where Dockerfile and csproj are

        - publish: '$(K8sManifestPath)' # Publish k8s manifests
          artifact: K8sManifests
          displayName: 'Publish Kubernetes Manifests'

    - stage: Deploy
      displayName: 'Deploy to AKS'
      dependsOn: Build
      condition: succeeded() # Only run if Build stage succeeded
      jobs:
      - deployment: DeployToAKS
        displayName: 'Deploy to AKS Job'
        environment: 'YourAKSAppEnvironment.default' # Create this environment in Azure DevOps > Pipelines > Environments
        strategy:
          runOnce:
            deploy:
              steps:
              - task: DownloadPipelineArtifact@2
                displayName: 'Download K8s Manifests'
                inputs:
                  artifactName: 'K8sManifests'
                  itemPattern: '**/*.yaml'
                  path: '$(Pipeline.Workspace)/manifests'

              # Create or Update Kubernetes Secret for Azure Storage Connection String
              # This step is sensitive. Use Azure Key Vault integration for production.
              # For simplicity, this example assumes you have a way to provide the secret value.
              # Using a pipeline variable marked as "secret" is one way.
              - task: KubernetesManifest@0
                displayName: 'Ensure Azure Storage Secret in AKS'
                inputs:
                  action: 'createSecret'
                  kubernetesServiceConnection: 'YourAKSServiceConnectionName' # Azure Resource Manager SC with K8s access
                  namespace: 'default' # Or your target namespace
                  secretType: 'generic'
                  secretName: 'azure-storage-secret'
                  secretArguments: '--from-literal=connectionstring=$(AzureStorageConnectionString)' # $(AzureStorageConnectionString) should be a secret pipeline variable

              - task: KubernetesManifest@0
                displayName: 'Deploy to Kubernetes cluster'
                inputs:
                  action: 'deploy'
                  kubernetesServiceConnection: 'YourAKSServiceConnectionName' # Azure Resource Manager SC with K8s access
                  namespace: 'default' # Or your target namespace
                  manifests: |
                    $(Pipeline.Workspace)/manifests/deployment.yaml
                    $(Pipeline.Workspace)/manifests/service.yaml
                  # For image substitution if image name in manifest is generic:
                  containers: '$(AcrName).azurecr.io/$(ImageRepository):$(TagName)'
                  # If your deployment.yaml directly references the ACR path, ensure it's parameterized
                  # or use `imagePullSecrets` if AKS doesn't have direct ACR rights (though --attach-acr handles this for `az aks create`)

    ```
    **Key points for `azure-pipelines.yml`:**
    *   **Service Connections:** Replace placeholders with your actual service connection names.
    *   **Secret Variable:** Define `AzureStorageConnectionString` as a secret variable in your Azure DevOps pipeline settings.
    *   **Environment:** Create an "Environment" in Azure DevOps (e.g., "DevAKS") and associate your AKS cluster with it for deployment approvals and traceability. The `environment` property in the deploy job refers to this.
    *   **Image Tagging:** Uses `Build.BuildId` for unique image tags.
    *   **`KubernetesManifest@0` task:** Used for applying manifests. The `containers` input helps substitute the correct image tag if your `deployment.yaml` uses a placeholder. If your `deployment.yaml` is already specific, you might not need `containers` input but ensure the YAML is updated or tokenized.
    *   **Secret Management:** The example uses `createSecret` for simplicity. For production, integrate Azure Key Vault with AKS (using CSI driver) and reference secrets from Key Vault in your deployment manifests. The pipeline would then focus on deploying manifests that expect secrets to be available via Key Vault.

3.  **Run the Pipeline:**
    *   Commit `azure-pipelines.yml` and the `k8s` manifests (ensure `secret.yaml` in repo is a template, not actual secrets).
    *   The pipeline should trigger, build the image, push to ACR, and deploy to AKS.

---

**Next Steps and Improvements:**

*   **Azure Key Vault:** Integrate for all secrets (Blob Connection String, API Keys, etc.). Use Managed Identities for AKS to access Key Vault.
*   **Advanced Kubernetes Deployments:** Consider Helm charts for packaging and managing K8s applications.
*   **Ingress Controller:** For more advanced routing, SSL termination (HTTPS), and path-based routing (e.g., Nginx Ingress, AGIC).
*   **Monitoring & Logging:** Integrate Azure Monitor for containers, set up distributed tracing, and structured logging.
*   **Testing:** Add comprehensive unit and integration tests to your pipeline.
*   **Configuration Management:** Use ConfigMaps in Kubernetes for non-sensitive configuration.
*   **Scalability:** Configure Horizontal Pod Autoscaler (HPA) in AKS.
*   **Security:** Regular vulnerability scanning of Docker images, network policies in AKS.
