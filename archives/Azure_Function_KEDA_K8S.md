# Azure Function KEDA K8S

- Common scenario: needing an internal operational tool deployed within Kubernetes to manage other Kubernetes resources. Using an Azure Function for this, deployed via KEDA (Kubernetes Event-driven Autoscaling) to host the Functions runtime, is a valid approach.

Let's break down why this is feasible and also discuss best practices and alternatives.

**Is this solution best practice?**

1.  **Azure Functions in Kubernetes (via KEDA):**
    *   **Pro:** If you're already familiar with the Azure Functions programming model, or if this API might evolve to include other event-driven triggers (e.g., reacting to queue messages, cron jobs), using Azure Functions with KEDA is a good choice. KEDA allows Azure Functions (and other scalers) to run and scale on any Kubernetes cluster.
    *   **Pro:** For simple HTTP triggers, it provides a lightweight framework.
    *   **Con (Minor):** For *just* a simple HTTP endpoint that interacts with the K8s API, a minimal ASP.NET Core Web API could also be used and might have slightly less overhead than the full Functions runtime. However, the difference for a low-traffic internal tool is likely negligible.

2.  **Directly Modifying HPAs via API:**
    *   **Pro:** Provides immediate, imperative control. Good for on-the-fly operational adjustments.
    *   **Con:** This is an imperative approach. The "source of truth" for the HPA's desired state can become fragmented if changes are only made via this API and not reflected in your declarative configuration (e.g., Helm charts, Kustomize manifests in Git).
    *   **Alternative (GitOps):** A more robust, declarative approach would be to have this API commit changes to a Git repository where your Kubernetes manifests are stored. A GitOps controller (like FluxCD or ArgoCD) running in the cluster would then automatically apply these changes. This gives you auditability, versioning, and rollback capabilities for your HPA configurations.
        *   **Why GitOps is often preferred for configuration changes:** It maintains a declarative desired state in Git. The API becomes a "helper" to update this desired state, rather than directly mutating live resources bypassing the declarative configuration.
    *   **When direct API is acceptable:** For internal tools, quick operational adjustments, or when the overhead of a full GitOps workflow for this specific task is deemed too high, a direct API can be acceptable. **Crucially, ensure this API is well-secured.**

3.  **Security:**
    *   The Azure Function pod will need a ServiceAccount with permissions to `get`, `list`, `watch`, and `patch` HorizontalPodAutoscalers (HPAs). This is a powerful permission.
    *   The HTTP endpoint (`/scale`) itself needs to be secured. Since it's an internal tool, network policies restricting access to specific internal services might be an initial step. For broader use, API key authentication or Azure AD authentication (if your cluster uses it) would be necessary for the Function's HTTP trigger. The prompt doesn't specify auth for the `/scale` endpoint, but it's vital.

**Recommendation:**

Using an Azure Function deployed via KEDA is a reasonable choice given your requirements. However, **strongly consider the GitOps alternative** for how the HPA configuration is ultimately updated if this tool needs to align with broader infrastructure-as-code practices. For now, we'll build the direct HPA modification as requested.

---

**Step-by-Step Implementation Plan:**

**Phase 1: Develop the Azure Function**
1.  Create an Azure Functions project (.NET 9, C# 12, Isolated Worker Model).
2.  Add HTTP triggers for `/scale` (POST) and `/health` (GET).
3.  Implement logic to interact with the Kubernetes API using the `KubernetesClient` library.
4.  Configure RBAC (ServiceAccount, Role, RoleBinding) for the Function.

**Phase 2: Dockerize the Azure Function**
1.  Create a Dockerfile suitable for .NET Isolated Azure Functions.

**Phase 3: Kubernetes Deployment**
1.  Install KEDA in your AKS cluster (if not already present).
2.  Create Kubernetes manifests:
    *   RBAC resources (ServiceAccount, Role, RoleBinding).
    *   `Deployment` for the Azure Function.
    *   `Service` to expose the Function on port 80.
    *   (No KEDA `ScaledObject` is needed for the function *itself* if it's just a constantly running HTTP endpoint. KEDA here is primarily to enable the Azure Functions runtime).

**Phase 4: Azure DevOps CI/CD Pipeline**
1.  Build the Function and Docker image.
2.  Push to ACR.
3.  Deploy K8s manifests to AKS.

---

**Phase 1: Develop the Azure Function**

1.  **Create New Azure Functions Project:**
    Make sure you have the Azure Functions Core Tools installed.
    ```bash
    # In your solutions directory
    mkdir HpaScalerFunction
    cd HpaScalerFunction
    func init . --worker-runtime dotnet-isolated --target-framework net9.0
    func new --name ScaleHpaHttp --template "HTTP trigger" --authlevel "anonymous" # For /scale, we'll refine auth later if needed
    func new --name HealthHttp --template "HTTP trigger" --authlevel "anonymous"   # For /health
    ```
    *   We'll use anonymous auth for now for simplicity in K8s, relying on K8s network policies or an Ingress for external access control later. For a production `/scale` endpoint, you'd want proper function-level or API gateway authentication.

2.  **Install NuGet Packages:**
    ```bash
    dotnet add package Microsoft.Azure.Functions.Worker.Sdk --version 1.17.0-preview2 # Or latest .NET 9 compatible
    dotnet add package Microsoft.Azure.Functions.Worker.Extensions.Http --version 3.1.0 # Or latest
    dotnet add package KubernetesClient --version 13.0.11 # Or latest stable
    dotnet add package Microsoft.Extensions.Logging.Console # For easier local logging
    ```
    *Ensure versions are compatible with .NET 9 previews.*

3.  **Define Request Model in `ScaleHpaHttp.cs` (or a separate Models file):**
    ```csharp
    // Models/ScaleRequest.cs (or within ScaleHpaHttp.cs)
    namespace HpaScalerFunction.Models;

    public class ScaleRequest
    {
        public string HpaName { get; set; }
        public int MinPods { get; set; }
        public int MaxPods { get; set; }
    }
    ```

4.  **Implement `ScaleHpaHttp.cs`:**
    ```csharp
    using Microsoft.Azure.Functions.Worker;
    using Microsoft.Azure.Functions.Worker.Http;
    using Microsoft.Extensions.Logging;
    using System.Net;
    using System.Text.Json;
    using k8s;
    using k8s.Models;
    using HpaScalerFunction.Models; // Your request model namespace

    namespace HpaScalerFunction
    {
        public class ScaleHpaHttp
        {
            private readonly ILogger<ScaleHpaHttp> _logger;
            private readonly Kubernetes _kubernetesClient;

            public ScaleHpaHttp(ILogger<ScaleHpaHttp> logger)
            {
                _logger = logger;
                try
                {
                    // Load in-cluster configuration
                    var config = KubernetesClientConfiguration.InClusterConfig();
                    _kubernetesClient = new Kubernetes(config);
                    _logger.LogInformation("Successfully loaded in-cluster Kubernetes config.");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to load in-cluster Kubernetes config. Trying local for dev.");
                    // Fallback for local development (requires kubectl proxy or config file)
                    // Ensure your KUBECONFIG env var is set or ~/.kube/config is valid
                    var config = KubernetesClientConfiguration.BuildDefaultConfig();
                    _kubernetesClient = new Kubernetes(config);
                    _logger.LogInformation("Successfully loaded local Kubernetes config.");
                }
            }

            [Function("ScaleHpa")] // Function name
            public async Task<HttpResponseData> Run(
                [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "scale")] HttpRequestData req)
            {
                _logger.LogInformation("C# HTTP trigger function 'ScaleHpa' processed a request.");
                string requestBody;
                try
                {
                    requestBody = await new StreamReader(req.Body).ReadToEndAsync();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error reading request body.");
                    var badReq = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badReq.WriteStringAsync("Could not read request body.");
                    return badReq;
                }

                if (string.IsNullOrEmpty(requestBody))
                {
                    var badReq = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badReq.WriteStringAsync("Request body is empty. Please pass HPA details in the request body.");
                    return badReq;
                }

                ScaleRequest? scaleData;
                try
                {
                    scaleData = JsonSerializer.Deserialize<ScaleRequest>(requestBody, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                }
                catch (JsonException ex)
                {
                    _logger.LogError(ex, "Error deserializing JSON request body.");
                    var badReq = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badReq.WriteStringAsync($"Invalid JSON format: {ex.Message}");
                    return badReq;
                }

                if (scaleData == null || string.IsNullOrWhiteSpace(scaleData.HpaName) || scaleData.MinPods <= 0 || scaleData.MaxPods < scaleData.MinPods)
                {
                    _logger.LogWarning("Invalid scale data received: {@ScaleData}", scaleData);
                    var badReq = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badReq.WriteStringAsync("Invalid data: HpaName is required, MinPods must be > 0, MaxPods >= MinPods.");
                    return badReq;
                }

                _logger.LogInformation("Attempting to scale HPA '{HpaName}' in namespace 'default' to Min: {MinPods}, Max: {MaxPods}",
                    scaleData.HpaName, scaleData.MinPods, scaleData.MaxPods);

                try
                {
                    // HPAs are usually in autoscaling/v2 or autoscaling/v1
                    // Let's try v2 first as it's more common for spec.minReplicas and spec.maxReplicas
                    V2HorizontalPodAutoscaler? hpaV2 = null;
                    try
                    {
                        hpaV2 = await _kubernetesClient.ReadNamespacedHorizontalPodAutoscalerAsync(scaleData.HpaName, "default");
                    }
                    catch (k8s.Autorest.HttpOperationException ex) when (ex.Response.StatusCode == HttpStatusCode.NotFound)
                    {
                        _logger.LogWarning("HPA '{HpaName}' not found using autoscaling/v2 API.", scaleData.HpaName);
                        // Try v1 if v2 not found (v1 uses spec.minReplicas and spec.maxReplicas fields as well)
                    }


                    if (hpaV2 != null)
                    {
                        if (hpaV2.Spec.MinReplicas == scaleData.MinPods && hpaV2.Spec.MaxReplicas == scaleData.MaxPods) {
                            _logger.LogInformation("HPA '{HpaName}' (v2) already configured with Min: {MinPods}, Max: {MaxPods}. No changes needed.", scaleData.HpaName, scaleData.MinPods, scaleData.MaxPods);
                            var noChangeResp = req.CreateResponse(HttpStatusCode.OK);
                            await noChangeResp.WriteStringAsync($"HPA '{scaleData.HpaName}' already at desired scale. No action taken.");
                            return noChangeResp;
                        }

                        hpaV2.Spec.MinReplicas = scaleData.MinPods;
                        hpaV2.Spec.MaxReplicas = scaleData.MaxPods;
                        await _kubernetesClient.ReplaceNamespacedHorizontalPodAutoscalerAsync(hpaV2, scaleData.HpaName, "default");
                        _logger.LogInformation("Successfully patched HPA '{HpaName}' (v2) to Min: {MinPods}, Max: {MaxPods}", scaleData.HpaName, scaleData.MinPods, scaleData.MaxPods);
                    }
                    else // Try v1
                    {
                        V1HorizontalPodAutoscaler? hpaV1 = null;
                         try
                        {
                            hpaV1 = await _kubernetesClient.ReadNamespacedHorizontalPodAutoscalerAsync1(scaleData.HpaName, "default"); // Note the method name difference
                        }
                        catch (k8s.Autorest.HttpOperationException ex) when (ex.Response.StatusCode == HttpStatusCode.NotFound)
                        {
                             _logger.LogError("HPA '{HpaName}' not found using autoscaling/v1 API either.", scaleData.HpaName);
                            var notFoundResp = req.CreateResponse(HttpStatusCode.NotFound);
                            await notFoundResp.WriteStringAsync($"HPA '{scaleData.HpaName}' not found in 'default' namespace using v1 or v2 HPA APIs.");
                            return notFoundResp;
                        }

                        if (hpaV1.Spec.MinReplicas == scaleData.MinPods && hpaV1.Spec.MaxReplicas == scaleData.MaxPods) {
                            _logger.LogInformation("HPA '{HpaName}' (v1) already configured with Min: {MinPods}, Max: {MaxPods}. No changes needed.", scaleData.HpaName, scaleData.MinPods, scaleData.MaxPods);
                            var noChangeResp = req.CreateResponse(HttpStatusCode.OK);
                            await noChangeResp.WriteStringAsync($"HPA '{scaleData.HpaName}' already at desired scale. No action taken.");
                            return noChangeResp;
                        }

                        hpaV1.Spec.MinReplicas = scaleData.MinPods;
                        hpaV1.Spec.MaxReplicas = scaleData.MaxPods;
                        await _kubernetesClient.ReplaceNamespacedHorizontalPodAutoscalerAsync1(hpaV1, scaleData.HpaName, "default");
                         _logger.LogInformation("Successfully patched HPA '{HpaName}' (v1) to Min: {MinPods}, Max: {MaxPods}", scaleData.HpaName, scaleData.MinPods, scaleData.MaxPods);
                    }

                    var response = req.CreateResponse(HttpStatusCode.OK);
                    await response.WriteStringAsync($"HPA '{scaleData.HpaName}' in 'default' namespace scaled to Min: {scaleData.MinPods}, Max: {scaleData.MaxPods}.");
                    return response;
                }
                catch (k8s.Autorest.HttpOperationException ex) when (ex.Response.StatusCode == HttpStatusCode.NotFound)
                {
                    _logger.LogError(ex, "HPA '{HpaName}' not found in 'default' namespace.", scaleData.HpaName);
                    var notFoundResp = req.CreateResponse(HttpStatusCode.NotFound);
                    await notFoundResp.WriteStringAsync($"HPA '{scaleData.HPAName}' not found in 'default' namespace.");
                    return notFoundResp;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error scaling HPA '{HpaName}'.", scaleData.HpaName);
                    var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                    await errorResponse.WriteStringAsync($"An error occurred: {ex.Message}");
                    return errorResponse;
                }
            }
        }
    }
    ```
    *   **Note on HPA versions:** HPAs can exist under `autoscaling/v1`, `autoscaling/v2beta2`, or `autoscaling/v2`. The client library has methods for these. The code attempts `v2` first, then `v1`. `ReplaceNamespacedHorizontalPodAutoscalerAsync` is used which replaces the whole object. For patching specific fields, you'd use `PatchNamespacedHorizontalPodAutoscalerAsync` with a `V1Patch` object. `Replace` is simpler if you're setting the whole spec part related to min/max.

5.  **Implement `HealthHttp.cs`:**
    ```csharp
    using Microsoft.Azure.Functions.Worker;
    using Microsoft.Azure.Functions.Worker.Http;
    using Microsoft.Extensions.Logging;
    using System.Net;

    namespace HpaScalerFunction
    {
        public class HealthHttp
        {
            private readonly ILogger<HealthHttp> _logger;

            public HealthHttp(ILogger<HealthHttp> logger)
            {
                _logger = logger;
            }

            [Function("Health")] // Function name
            public HttpResponseData Run(
                [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequestData req)
            {
                _logger.LogInformation("C# HTTP trigger function 'Health' processed a request.");
                var response = req.CreateResponse(HttpStatusCode.OK);
                response.Headers.Add("Content-Type", "text/plain; charset=utf-8");
                response.WriteString("Healthy");
                return response;
            }
        }
    }
    ```

6.  **Update `Program.cs` for DI and Logging:**
    ```csharp
    using Microsoft.Extensions.Hosting;
    using Microsoft.Extensions.DependencyInjection;
    using Microsoft.Extensions.Logging; // Required for AddLogging

    var host = new HostBuilder()
        .ConfigureFunctionsWorkerDefaults()
        .ConfigureServices(services => {
            // Kubernetes client is instantiated directly in the function for now
            // due to its config loading logic (in-cluster vs. local).
            // If you wanted to inject it, you'd need a factory or more complex setup
            // to handle the different configuration scenarios.
            // For a K8s-only deployment, you could register it as a singleton:
            // services.AddSingleton<k8s.IKubernetes>(sp => {
            //     var config = k8s.KubernetesClientConfiguration.InClusterConfig();
            //     return new k8s.Kubernetes(config);
            // });
        })
        .ConfigureLogging(logging => { // Optional: Add console logging for local dev
            logging.AddConsole();
        })
        .Build();

    host.Run();
    ```

7.  **Local Development Settings (`local.settings.json`):**
    For Azure Functions, the K8s client will try to use `~/.kube/config` or `KUBECONFIG` env var when not in-cluster. Ensure your `kubectl` context points to your AKS cluster.
    ```json
    {
      "IsEncrypted": false,
      "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true", // Or your actual storage conn string
        "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated"
        // No specific K8s settings needed here if using default local config
      }
    }
    ```
    *   You can test locally with `func start`. Send a POST to `http://localhost:7071/api/scale` (port may vary).

---

**Phase 2: Dockerize the Azure Function**

1.  **Create `Dockerfile` in the `HpaScalerFunction` project root:**
    ```dockerfile
    # Base image for .NET 9 Isolated Azure Functions
    # Check MCR for the latest .NET 9 preview tag for azure-functions/dotnet-isolated
    # Example: mcr.microsoft.com/azure-functions/dotnet-isolated:4-dotnet-isolated9.0-preview
    # As of writing, a specific 9.0 tag might not be public, use 8.0 as a placeholder structure and update when available
    # For now, let's assume a .NET 9 base image will exist with a similar structure
    # For .NET 9, the tag might be like: mcr.microsoft.com/azure-functions/dotnet-isolated:5-dotnet-isolated9.0 (Functions v5 runtime for .NET 9)
    # The current latest available tag for a preview is often mcr.microsoft.com/azure-functions/dotnet-isolated:4-dotnet-isolated8.0 or similar for .NET 8
    # ADJUST THE BASE IMAGE ACCORDING TO AVAILABLE .NET 9 FUNCTION BASE IMAGES
    FROM mcr.microsoft.com/azure-functions/dotnet-isolated:4-dotnet-isolated8.0 AS base
    # For .NET 9, it might be something like:
    # FROM mcr.microsoft.com/azure-functions/dotnet-isolated:4-dotnet-isolated9.0-preview
    # OR (when Functions V5 runtime is more broadly available for .NET 9):
    # FROM mcr.microsoft.com/azure-functions/dotnet-isolated:5-dotnet-isolated9.0-preview
    # For now, this structure is based on .NET 8 isolated, which should be very similar.

    WORKDIR /home/site/wwwroot
    ENV AzureWebJobsScriptRoot=/home/site/wwwroot
    ENV FUNCTIONS_WORKER_RUNTIME=dotnet-isolated
    # Optional: If you need to specify the port Functions host listens on internally
    # ENV FUNCTIONS_HTTPWORKER_PORT=8080

    # Build stage
    FROM mcr.microsoft.com/dotnet/sdk:9.0-preview AS build
    WORKDIR /src
    COPY ["HpaScalerFunction.csproj", "./"]
    RUN dotnet restore "./HpaScalerFunction.csproj"
    COPY . .
    RUN dotnet publish "HpaScalerFunction.csproj" -c Release -o /app/publish /p:UseAppHost=false

    # Final stage
    FROM base AS final
    WORKDIR /home/site/wwwroot
    COPY --from=build /app/publish .

    # The Azure Functions host will listen on its configured port (typically 8080 for HTTP in isolated worker)
    # The K8s service will map external port 80 to this internal port.
    ```
    *   **IMPORTANT:** The base image tag for `.NET 9 Isolated Azure Functions` needs to be confirmed once official/preview images are readily available on MCR. The structure shown is typical for .NET isolated functions.
    *   The Azure Functions host usually listens on port `8080` internally in Docker when configured for HTTP. `WEBSITES_PORT` or `FUNCTIONS_HTTPWORKER_PORT` can influence this. We'll let the K8s service handle mapping external port 80.

---

**Phase 3: Kubernetes Deployment**

1.  **Install KEDA (if not already installed):**
    Follow instructions at [keda.sh/docs/latest/deploy/](https://keda.sh/docs/latest/deploy/) (e.g., using Helm).
    ```bash
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update
    helm install keda kedacore/keda --namespace keda --create-namespace
    ```

2.  **Create Kubernetes Manifests:**
    Create a `k8s` folder in your `HpaScalerFunction` project.

    `k8s/rbac.yaml`:
    ```yaml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: hpa-scaler-sa
      namespace: default # Or your target namespace
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      namespace: default # Or your target namespace
      name: hpa-editor-role
    rules:
    - apiGroups: ["autoscaling"] # Covers v1, v2beta2, v2 of HPA
      resources: ["horizontalpodautoscalers"]
      verbs: ["get", "list", "watch", "patch", "update", "replace"] # Replace is used in the C# code
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: hpa-scaler-hpa-editor-binding
      namespace: default # Or your target namespace
    subjects:
    - kind: ServiceAccount
      name: hpa-scaler-sa
      namespace: default # Or your target namespace
    roleRef:
      kind: Role
      name: hpa-editor-role
      apiGroup: rbac.authorization.k8s.io
    ```

    `k8s/deployment.yaml`:
    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: hpa-scaler-function-deployment
      namespace: default # Or your target namespace
      labels:
        app: hpa-scaler-function
    spec:
      replicas: 1 # Typically 1-2 replicas for such an internal tool
      selector:
        matchLabels:
          app: hpa-scaler-function
      template:
        metadata:
          labels:
            app: hpa-scaler-function
        spec:
          serviceAccountName: hpa-scaler-sa # Use the ServiceAccount defined in rbac.yaml
          containers:
          - name: hpa-scaler-function
            image: youruniqueacrname.azurecr.io/hpascalerfunction:latest # Replace with your ACR and image tag
            ports:
            - containerPort: 8080 # Default port Azure Functions HTTP worker listens on. Adjust if your Dockerfile sets a different FUNCTIONS_HTTPWORKER_PORT
            # It's good practice to set resource requests and limits
            resources:
              requests:
                memory: "128Mi"
                cpu: "100m"
              limits:
                memory: "256Mi"
                cpu: "500m"
            # Liveness and Readiness probes using the /health endpoint
            livenessProbe:
              httpGet:
                path: /api/health # Route defined in HealthHttp.cs
                port: 8080 # Port container listens on
              initialDelaySeconds: 15
              periodSeconds: 30
              timeoutSeconds: 5
              failureThreshold: 3
            readinessProbe:
              httpGet:
                path: /api/health
                port: 8080
              initialDelaySeconds: 5
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
    ```
    *   **`containerPort`**: The Azure Functions host in an isolated worker typically listens on port 8080 for HTTP requests inside the container. If you override this with `FUNCTIONS_HTTPWORKER_PORT` in the Dockerfile or deployment, update it here.

    `k8s/service.yaml`:
    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: hpa-scaler-function-service
      namespace: default # Or your target namespace
      labels:
        app: hpa-scaler-function
    spec:
      type: ClusterIP # Internal service, typically. Use LoadBalancer if external access is needed directly (not common for this type of tool).
      ports:
      - port: 80 # The port the service will listen on within the cluster
        targetPort: 8080 # The port the container (Function) is listening on
        protocol: TCP
        name: http
      selector:
        app: hpa-scaler-function # Must match labels on the Deployment's pods
    ```
    *   This service makes your function available at `http://hpa-scaler-function-service.default.svc.cluster.local/api/scale` (and `/api/health`) from within the cluster.

---

**Phase 4: Azure DevOps CI/CD Pipeline**

Update your `azure-pipelines.yml`:
```yaml
trigger:
- main # Or your development branch

pool:
  vmImage: 'ubuntu-latest'

variables:
  BuildConfiguration: 'Release'
  ProjectName: 'HpaScalerFunction' # Name of your Function project
  DockerRegistryServiceConnection: 'YourACRServiceConnectionName'
  ImageRepository: 'hpascalerfunction' # Image name in ACR
  AcrName: 'youruniqueacrname'
  TagName: '$(Build.BuildId)'
  K8sManifestPath: '$(Build.SourcesDirectory)/$(ProjectName)/k8s' # Path to k8s manifests
  K8sNamespace: 'default' # Target Kubernetes namespace
  K8sServiceConnection: 'YourAKSServiceConnectionName' # Azure Resource Manager SC with K8s access

stages:
- stage: Build
  displayName: 'Build Azure Function and Docker Image'
  jobs:
  - job: BuildAndPush
    displayName: 'Build, Test, and Push'
    steps:
    - task: UseDotNet@2
      displayName: 'Use .NET 9 SDK Preview'
      inputs:
        packageType: 'sdk'
        version: '9.0.x' # Ensure this matches your project's target
        performMultiLevelLookup: true
        includePreviewVersions: true

    - task: DotNetCoreCLI@2
      displayName: 'Restore NuGet Packages'
      inputs:
        command: 'restore'
        projects: '$(Build.SourcesDirectory)/$(ProjectName)/$(ProjectName).csproj'
        feedsToUse: 'select'

    - task: DotNetCoreCLI@2
      displayName: 'Build Azure Function'
      inputs:
        command: 'build'
        projects: '$(Build.SourcesDirectory)/$(ProjectName)/$(ProjectName).csproj'
        arguments: '--configuration $(BuildConfiguration)'

    # Add unit tests if any

    - task: DotNetCoreCLI@2
      displayName: 'Publish Azure Function'
      inputs:
        command: 'publish'
        publishWebProjects: false # Not a web project in the traditional sense
        projects: '$(Build.SourcesDirectory)/$(ProjectName)/$(ProjectName).csproj'
        arguments: '--configuration $(BuildConfiguration) --output $(Build.ArtifactStagingDirectory)/publish'
        zipAfterPublish: false # We need the raw files for Docker

    - task: Docker@2
      displayName: 'Build and Push Docker Image to ACR'
      inputs:
        command: 'buildAndPush'
        repository: '$(ImageRepository)'
        dockerfile: '$(Build.SourcesDirectory)/$(ProjectName)/Dockerfile'
        containerRegistry: '$(DockerRegistryServiceConnection)'
        tags: |
          $(TagName)
          latest
        buildContext: '$(Build.SourcesDirectory)/$(ProjectName)' # Context is the Function project dir

    - publish: '$(K8sManifestPath)'
      artifact: K8sManifests
      displayName: 'Publish Kubernetes Manifests'

- stage: Deploy
  displayName: 'Deploy to AKS'
  dependsOn: Build
  condition: succeeded()
  jobs:
  - deployment: DeployToAKS
    displayName: 'Deploy to AKS Job'
    environment: 'YourAKSAppEnvironment.default' # Your Azure DevOps Environment for AKS
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

          - task: KubernetesManifest@0
            displayName: 'Apply RBAC for HPA Scaler Function'
            inputs:
              action: 'apply' # Apply will create or update
              kubernetesServiceConnection: '$(K8sServiceConnection)'
              namespace: '$(K8sNamespace)'
              manifests: '$(Pipeline.Workspace)/manifests/rbac.yaml'

          - task: KubernetesManifest@0
            displayName: 'Deploy HPA Scaler Function to AKS'
            inputs:
              action: 'apply' # Apply will create or update
              kubernetesServiceConnection: '$(K8sServiceConnection)'
              namespace: '$(K8sNamespace)'
              manifests: |
                $(Pipeline.Workspace)/manifests/deployment.yaml
                $(Pipeline.Workspace)/manifests/service.yaml
              # Substitute the image in the deployment.yaml
              # Ensure deployment.yaml uses a placeholder or this overrides it
              containers: '$(AcrName).azurecr.io/$(ImageRepository):$(TagName)'
```

**Important Considerations:**

*   **Error Handling & Idempotency in Function:** The HPA update logic should be robust. The current code checks if the HPA is already at the desired scale to avoid unnecessary updates.
*   **Security for `/scale` endpoint:** For production, you **must** secure this endpoint. Options:
    *   Function App Keys (if using API Management in front or if KEDA can enforce this).
    *   Azure AD authentication (more complex to set up for pod-to-pod).
    *   Mutual TLS.
    *   Network Policies in K8s to restrict which pods can call this service.
    *   If exposed via an Ingress, the Ingress controller can handle authentication.
*   **TargetPort in Service:** Ensure `targetPort` in `k8s/service.yaml` matches the port your Azure Function's Docker container is actually listening on (likely 8080, but verify based on the final .NET 9 Azure Function base image behavior or `FUNCTIONS_HTTPWORKER_PORT` if set).
*   **.NET 9 Function Base Image:** Keep an eye on the Microsoft Container Registry (MCR) for the official `.NET 9 preview` base images for `azure-functions/dotnet-isolated`. The Dockerfile provided uses `.NET 8` as a structural placeholder and will need updating.

### Update v2

You're right, for liveness and readiness probes in Kubernetes, you don't necessarily need a separate Azure Function endpoint (`/api/health`). The Azure Functions host itself, when running HTTP triggers, often exposes an implicit health check or can be configured for one, and Kubernetes probes can target any valid path on your function that indicates health.

However, having an explicit, simple `/api/health` (or similar) endpoint that does minimal work is a common and clear pattern for K8s probes. If the main `/api/scale` endpoint requires a complex POST body, it's not ideal for simple GET probes. So, an explicit health endpoint is still a good practice.

If you *really* want to avoid a separate function file for health, and your `/api/scale` endpoint is on the `ScaleHpaHttp` function, you could configure probes to hit `/api/scale` with a GET request. Azure Functions typically return a `405 Method Not Allowed` for GET requests to a POST-only function. Kubernetes probes often consider any `2xx-3xx` response as healthy by default (some might treat `405` as unhealthy depending on configuration). This is less clean than a dedicated health endpoint.

**Let's stick with the explicit `HealthHttp.cs` for clarity in probes but simplify its setup.**

Here are the requested file examples:

**1. `HpaScalerFunction.csproj`**

This `.csproj` file is for an Azure Function using the .NET Isolated Worker model, targeting .NET 9.0.

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <AzureFunctionsVersion>v4</AzureFunctionsVersion> <!-- Or v5 if that aligns with .NET 9 by GA -->
    <OutputType>Exe</OutputType>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <!-- Set this to true if you are using preview SDKs/runtimes for .NET 9 -->
    <EnablePreviewFeatures>True</EnablePreviewFeatures>
    <!-- LangVersion for C# 12 features -->
    <LangVersion>12.0</LangVersion>
  </PropertyGroup>

  <ItemGroup>
    <!-- Core Azure Functions Worker SDK -->
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.0-preview2" />
    <!-- HTTP Trigger support for Isolated Worker -->
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.1.0" />
    <!-- Kubernetes Client Library -->
    <PackageReference Include="KubernetesClient" Version="13.0.11" />
    <!-- For Console Logging (useful for local dev and container logs) -->
    <PackageReference Include="Microsoft.Extensions.Logging.Console" Version="8.0.0" />
     <!-- Application Insights for Azure Functions (Optional but Recommended) -->
    <PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="1.2.0" />
  </ItemGroup>

  <ItemGroup>
    <!-- These files are typically part of an Azure Functions project -->
    <None Update="host.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
    <None Update="local.settings.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
      <CopyToPublishDirectory>Never</CopyToPublishDirectory>
    </None>
  </ItemGroup>

  <ItemGroup>
    <!-- If you have a separate Models folder -->
    <Compile Include="Models\ScaleRequest.cs" />
  </ItemGroup>

</Project>
```

**Key points in `.csproj`:**
*   **`<TargetFramework>net9.0</TargetFramework>`**: Specifies .NET 9.
*   **`<AzureFunctionsVersion>v4</AzureFunctionsVersion>`**: This indicates the Azure Functions runtime version. For .NET 8/9 isolated, v4 is common. If a Functions v5 runtime becomes the standard for .NET 9, this might need updating.
*   **`<OutputType>Exe</OutputType>`**: Required for .NET Isolated Worker model.
*   **`<EnablePreviewFeatures>True</EnablePreviewFeatures>`**: Good to include if you're actively using .NET 9 preview features or SDKs.
*   **`<LangVersion>12.0</LangVersion>`**: To enable C# 12 features.
*   **Package References:**
    *   `Microsoft.Azure.Functions.Worker.Sdk`: Core SDK for building functions.
    *   `Microsoft.Azure.Functions.Worker.Extensions.Http`: For HTTP triggers.
    *   `KubernetesClient`: For interacting with the Kubernetes API.
    *   `Microsoft.Extensions.Logging.Console`: For seeing logs in the console locally and in container logs.
    *   `Microsoft.Azure.Functions.Worker.ApplicationInsights`: (Optional but highly recommended for production) For sending telemetry to Application Insights.
*   **`<None Update="...">`**: Ensures `host.json` and `local.settings.json` are handled correctly during build and publish.

**2. `host.json`**

This file contains global configuration options that affect all functions in the function app. For your use case, the defaults are often fine, but you'll want logging configured, and extension bundle information if you were using non-HTTP triggers that require them (not strictly needed for pure HTTP + K8s client).

```json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "excludedTypes": "Request" // Exclude Request telemetry if it's too noisy, or adjust sampling
      },
      "enableLiveMetricsFilters": true // Enables filtering for Live Metrics
    },
    "logLevel": {
      // Default log level for all categories
      "Default": "Information",
      // Override for specific categories
      "Host.Results": "Information", // Logs function execution results
      "Function": "Information",     // Logs from your function code (ILogger)
      "HpaScalerFunction": "Debug", // Set your function's namespace to Debug for more verbose logs if needed
      "k8s": "Information"          // Log level for the KubernetesClient library
    }
  },
  // Extension bundles are generally for non-HTTP triggers (e.g., Timer, Queue).
  // For a purely HTTP-triggered function running in Kubernetes, you might not explicitly need it
  // if all extensions are managed via NuGet packages (like Worker.Extensions.Http).
  // If you were deploying to Azure Functions PaaS and using binding extensions not covered by the isolated worker's model,
  // you would need this. For KEDA deployments, it's less critical unless KEDA itself or other functions need it.
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)" // Use a version range compatible with Functions v4 runtime
  },
  "extensions": {
    "http": {
      // Default route prefix is "api". If you want to change it (e.g., to empty string for /scale directly),
      // you can set it here. However, having "api" is standard.
      // "routePrefix": ""
    }
  }
}
```

**Key points in `host.json`:**
*   **`version: "2.0"`**: Standard for current Functions runtime.
*   **`logging`**:
    *   Configures Application Insights (if you add the package). Sampling is important to manage costs and data volume.
    *   `logLevel`: Allows you to control the verbosity of logs. Set `"Default": "Information"`. You can override for specific categories like your function's namespace (`"HpaScalerFunction": "Debug"`) or the Kubernetes client (`"k8s": "Information"`).
*   **`extensionBundle`**: While the HTTP extension is now part of the isolated worker model via NuGet, keeping the bundle definition is common practice and generally harmless. It primarily helps with other binding types if you were to add them. For a KEDA deployment of a pure HTTP function, it might not be strictly necessary, but it doesn't hurt.
*   **`extensions.http.routePrefix`**: By default, all HTTP triggered functions will have `/api/` prefixed to their route. So, `Route = "scale"` becomes `/api/scale`. This is usually desirable. If you want functions directly at the root (e.g., `/scale`), you can set `"routePrefix": ""`.

**Revisiting Health Checks for K8s Probes:**

As discussed, an explicit `/api/health` endpoint is generally good. If you choose to keep `HealthHttp.cs`, ensure its route is unique (e.g., `Route = "health"`). Your K8s deployment probes would then point to `/api/health`.

**Deployment Manifests and Probes:**

In `k8s/deployment.yaml`, the probes would look like this if you keep the `HealthHttp.cs` function:

```yaml
# ... (rest of deployment.yaml)
            livenessProbe:
              httpGet:
                path: /api/health # Route defined in HealthHttp.cs for the "Health" function
                port: 8080       # Port the container (Functions host) listens on
              initialDelaySeconds: 20 # Give it more time to start
              periodSeconds: 30
              # ... other probe settings
            readinessProbe:
              httpGet:
                path: /api/health
                port: 8080
              initialDelaySeconds: 10
              periodSeconds: 15
              # ... other probe settings
```

If you decide to *not* have a separate `HealthHttp.cs` and want to probe the Functions host itself:
The Azure Functions host typically doesn't expose a generic `/` health endpoint by default that's guaranteed to work for probes in all scenarios without specific configuration. Probing an actual function endpoint (like `/api/scale` with a GET, which might return 405) is less ideal.

**Recommendation:** **Keep the simple, explicit `HealthHttp.cs` function and the corresponding `/api/health` endpoint.** It's a clean, standard way to integrate with Kubernetes liveness and readiness probes. It adds minimal code and provides a clear contract for health checking.

With these files and clarifications, your Azure Function project structure should be robust and ready for deployment.
