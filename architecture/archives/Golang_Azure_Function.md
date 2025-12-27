Okay, this is a common scenario for proactively managing workloads based on queue backlogs. We'll build two Azure Functions in Go (as it's well-suited for this kind of task and has good Azure SDK support). They will use System-Assigned Managed Identities for Azure resource authentication.

**Overall Architecture:**

1.  **`check_sa_queue` (Timer Trigger Function):**
    *   Runs on a schedule (e.g., every 1-5 minutes).
    *   Uses its Managed Identity to access the Storage Account Queue.
    *   Retrieves the current queue depth.
    *   Stores the previous depth and timestamp (e.g., in Azure Table Storage, or a simple blob if only one queue is monitored by this function instance) to calculate the growth rate.
    *   If depth > `THRESHOLD` AND growth rate > `GROWTH_RATE_THRESHOLD`, it calls `increase_hpa_aks` via an HTTP request.

2.  **`increase_hpa_aks` (HTTP Trigger Function):**
    *   Receives an HTTP request from `check_sa_queue`.
    *   Uses its Managed Identity to authenticate with the Azure Resource Manager (ARM) to get credentials for the AKS cluster.
    *   Uses the Kubernetes Go client library to connect to the AKS API server.
    *   Patches the specified HorizontalPodAutoscaler (HPA) object to increase its `maxReplicas`.

**Resource Names (from your request):**
*   Dev Resource Group: `rg-cds-optmz-dev`
*   Dev AKS Cluster Name: `cdsaksclusterdev`

**Let's define some additional names we'll need:**
*   Storage Account Name (you'll need to provide this): `YOUR_STORAGE_ACCOUNT_NAME`
*   Storage Queue Name (you'll need to provide this): `YOUR_QUEUE_NAME`
*   Function App for `check_sa_queue`: `checksaqueuefuncapp` (example, choose your unique name)
*   Function App for `increase_hpa_aks`: `increasehpafuncapp` (example, choose your unique name)
*   Table Storage for state (optional but recommended for `check_sa_queue`): `queuemonitorstate`
*   Target HPA Name in AKS: `YOUR_HPA_NAME`
*   Target HPA Namespace in AKS: `YOUR_HPA_NAMESPACE` (e.g., `default`)

---

**Step 1: Prerequisites**

1.  **Azure CLI:** Install and log in (`az login`).
2.  **Go:** Install Go (1.18+ recommended).
3.  **Azure Functions Core Tools:** Install version 4.x (`npm install -g azure-functions-core-tools@4 --unsafe-perm true`).
4.  **Git:** For version control.

---

**Step 2: Create Azure Function Apps and Enable Managed Identities**

For each function (`check_sa_queue` and `increase_hpa_aks`), we'll create a separate Function App. This provides better isolation of permissions and concerns.

```bash
# Variables
RESOURCE_GROUP="rg-cds-optmz-dev"
LOCATION="eastus" # Or your preferred location
STORAGE_ACCOUNT_FUNC_CHECK="checksaqueuestfunc" # Unique name for Function's storage
STORAGE_ACCOUNT_FUNC_SCALE="increasehpastfunc"   # Unique name for Function's storage
FUNCTION_APP_CHECK_NAME="checksaqueuefuncapp-$(openssl rand -hex 3)" # Unique name
FUNCTION_APP_SCALE_NAME="increasehpafuncapp-$(openssl rand -hex 3)" # Unique name
YOUR_MONITORED_STORAGE_ACCOUNT_NAME="YOUR_STORAGE_ACCOUNT_NAME" # The SA with the queue
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create storage accounts for the Function Apps
az storage account create --name $STORAGE_ACCOUNT_FUNC_CHECK --location $LOCATION --resource-group $RESOURCE_GROUP --sku Standard_LRS
az storage account create --name $STORAGE_ACCOUNT_FUNC_SCALE --location $LOCATION --resource-group $RESOURCE_GROUP --sku Standard_LRS

# Create Function App for check_sa_queue
az functionapp create --name $FUNCTION_APP_CHECK_NAME \
  --storage-account $STORAGE_ACCOUNT_FUNC_CHECK \
  --consumption-plan-location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --os-type Linux \
  --runtime golang \
  --runtime-version 1.19 \
  --functions-version 4 \
  --assign-identity "[system]"

# Create Function App for increase_hpa_aks
az functionapp create --name $FUNCTION_APP_SCALE_NAME \
  --storage-account $STORAGE_ACCOUNT_FUNC_SCALE \
  --consumption-plan-location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --os-type Linux \
  --runtime golang \
  --runtime-version 1.19 \
  --functions-version 4 \
  --assign-identity "[system]"

# Get Managed Identity Object IDs
CHECK_FUNC_MI_PRINCIPAL_ID=$(az functionapp identity show --name $FUNCTION_APP_CHECK_NAME --resource-group $RESOURCE_GROUP --query principalId -o tsv)
SCALE_FUNC_MI_PRINCIPAL_ID=$(az functionapp identity show --name $FUNCTION_APP_SCALE_NAME --resource-group $RESOURCE_GROUP --query principalId -o tsv)

echo "Checker Function App MI Principal ID: $CHECK_FUNC_MI_PRINCIPAL_ID"
echo "Scaler Function App MI Principal ID: $SCALE_FUNC_MI_PRINCIPAL_ID"
```

---

**Step 3: Assign Permissions to Managed Identities**

1.  **`check_sa_queue` Function (Checker) Permissions:**
    *   Needs to read queue properties from your target Storage Account.
    *   Needs to read/write to a Table in its *own* storage account (or a dedicated one) for storing state.

    ```bash
    # Permission to read the target queue
    # Replace YOUR_STORAGE_ACCOUNT_NAME with the actual storage account name
    TARGET_SA_RESOURCE_ID=$(az storage account show --name $YOUR_MONITORED_STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)
    az role assignment create --assignee $CHECK_FUNC_MI_PRINCIPAL_ID \
      --role "Storage Queue Data Reader" \
      --scope $TARGET_SA_RESOURCE_ID

    # Permission for state table (using the checker function's own storage account)
    # This creates a table named 'queuestatestore'
    CHECK_FUNC_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $STORAGE_ACCOUNT_FUNC_CHECK --resource-group $RESOURCE_GROUP --query connectionString -o tsv)
    az storage table create --name queuestatestore --connection-string "$CHECK_FUNC_STORAGE_CONNECTION_STRING"

    CHECK_FUNC_SA_RESOURCE_ID=$(az storage account show --name $STORAGE_ACCOUNT_FUNC_CHECK --resource-group $RESOURCE_GROUP --query id -o tsv)
    az role assignment create --assignee $CHECK_FUNC_MI_PRINCIPAL_ID \
        --role "Storage Table Data Contributor" \
        --scope "${CHECK_FUNC_SA_RESOURCE_ID}/tableServices/default/tables/queuestatestore"
    ```

2.  **`increase_hpa_aks` Function (Scaler) Permissions:**
    *   Needs to get AKS cluster admin credentials.
    *   Needs to interact with the Kubernetes API to modify HPA. The "Azure Kubernetes Service Cluster Admin Role" is broad; for production, scope this down using Kubernetes RBAC if possible.

    ```bash
    AKS_RESOURCE_ID=$(az aks show --name "cdsaksclusterdev" --resource-group $RESOURCE_GROUP --query id -o tsv)

    # Grant permission to get cluster admin credentials and interact with AKS
    az role assignment create --assignee $SCALE_FUNC_MI_PRINCIPAL_ID \
      --role "Azure Kubernetes Service Cluster Admin Role" \
      --scope $AKS_RESOURCE_ID
    ```
    **Note on AKS Permissions:** The "Azure Kubernetes Service Cluster Admin Role" gives the Managed Identity full control over the AKS cluster via the Azure control plane *and* implies admin access within the Kubernetes RBAC system. For a more restricted setup, you might assign "Azure Kubernetes Service Cluster User Role" (to get kubeconfig) and then create a specific `Role` and `RoleBinding` *within* Kubernetes to grant the Function App's Managed Identity (identified by its Object ID) permissions to only patch HPAs in a specific namespace. However, the admin role is simpler for this example.

---

**Step 4: Develop the `check_sa_queue` Azure Function (Go)**

1.  **Initialize Function Project:**
    ```bash
    mkdir check_sa_queue_project && cd check_sa_queue_project
    func init --worker-runtime go
    func new --name check_sa_queue --template "Timer trigger"
    ```
    Edit `check_sa_queue/function.json` for your desired schedule (e.g., every minute):
    ```json
    {
      "bindings": [
        {
          "name": "myTimer",
          "type": "timerTrigger",
          "direction": "in",
          "schedule": "0 */1 * * * *" // Every 1 minute
        }
      ],
      "scriptFile": "../handler.go" // We'll move the Go file to the root
    }
    ```
    Note: We'll create a single `handler.go` in the project root to simplify structure for multiple functions if you were to add more. If it's just one, you can keep it inside `check_sa_queue/run.go`. For this example, let's assume `handler.go` in the root.

2.  **Create `handler.go` in `check_sa_queue_project` root:**
    ```go
    package main

    import (
        "context"
        "encoding/json"
        "fmt"
        "log"
        "net/http"
        "os"
        "strconv"
        "strings"
        "time"

        "github.com/Azure/azure-sdk-for-go/sdk/azcore/to"
        "github.com/Azure/azure-sdk-for-go/sdk/azidentity"
        "github.com/Azure/azure-sdk-for-go/sdk/data/aztables"
        "github.com/Azure/azure-sdk-for-go/sdk/storage/azqueue"
    )

    // StateEntity represents the structure for storing queue state in Azure Table Storage
    type StateEntity struct {
        aztables.Entity
        LastDepth     int32     `json:"LastDepth"`
        LastCheckTime time.Time `json:"LastCheckTime"`
    }

    // TimerFunctionInvoked is for Azure Functions logging
    type TimerFunctionInvoked struct {
        Data     map[string]interface{}
        Metadata map[string]interface{}
    }

    // CheckSaQueue is the main function logic
    func CheckSaQueue(ctx context.Context, myTimer TimerFunctionInvoked, log *log.Logger) error {
        log.Printf("check_sa_queue function triggered at: %s", time.Now().Format(time.RFC3339))

        monitoredStorageAccountName := os.Getenv("MONITORED_STORAGE_ACCOUNT_NAME")
        monitoredQueueName := os.Getenv("MONITORED_QUEUE_NAME")
        depthThresholdStr := os.Getenv("DEPTH_THRESHOLD")
        growthRateThresholdPercentStr := os.Getenv("GROWTH_RATE_THRESHOLD_PERCENT") // e.g., 50 for 50%
        growthCheckIntervalSecondsStr := os.Getenv("GROWTH_CHECK_INTERVAL_SECONDS") // e.g., 300 for 5 mins
        scalerFunctionURL := os.Getenv("SCALER_FUNCTION_URL")
        scalerFunctionKey := os.Getenv("SCALER_FUNCTION_KEY") // Optional: for function key auth

        stateStorageAccountName := os.Getenv("STATE_STORAGE_ACCOUNT_NAME") // SA where the state table resides
        stateTableName := os.Getenv("STATE_TABLE_NAME")                   // e.g., "queuestatestore"

        if monitoredStorageAccountName == "" || monitoredQueueName == "" || depthThresholdStr == "" ||
            growthRateThresholdPercentStr == "" || growthCheckIntervalSecondsStr == "" || scalerFunctionURL == "" ||
            stateStorageAccountName == "" || stateTableName == "" {
            log.Println("Error: Missing one or more required environment variables.")
            return fmt.Errorf("missing environment variables")
        }

        depthThreshold, err := strconv.Atoi(depthThresholdStr)
        if err != nil {
            log.Printf("Error parsing DEPTH_THRESHOLD: %v", err)
            return err
        }
        growthRateThresholdPercent, err := strconv.ParseFloat(growthRateThresholdPercentStr, 64)
        if err != nil {
            log.Printf("Error parsing GROWTH_RATE_THRESHOLD_PERCENT: %v", err)
            return err
        }
        growthCheckIntervalSeconds, err := strconv.Atoi(growthCheckIntervalSecondsStr)
        if err != nil {
            log.Printf("Error parsing GROWTH_CHECK_INTERVAL_SECONDS: %v", err)
            return err
        }

        // --- 1. Get Azure Credentials using Managed Identity ---
        cred, err := azidentity.NewDefaultAzureCredential(nil)
        if err != nil {
            log.Printf("Error creating default Azure credential: %v", err)
            return err
        }

        // --- 2. Get Current Queue Depth ---
        queueServiceURL := fmt.Sprintf("https://%s.queue.core.windows.net/", monitoredStorageAccountName)
        queueClient, err := azqueue.NewServiceClient(queueServiceURL, cred, nil)
        if err != nil {
            log.Printf("Error creating queue service client: %v", err)
            return err
        }
        qClient := queueClient.NewQueueClient(monitoredQueueName)
        props, err := qClient.GetProperties(ctx, nil)
        if err != nil {
            log.Printf("Error getting queue properties for %s: %v", monitoredQueueName, err)
            return err
        }
        currentDepth := *props.ApproximateMessagesCount
        log.Printf("Queue: %s, Current Depth: %d", monitoredQueueName, currentDepth)

        // --- 3. Get Previous State from Table Storage ---
        tableServiceURL := fmt.Sprintf("https://%s.table.core.windows.net/", stateStorageAccountName)
        stateTableClient, err := aztables.NewServiceClient(tableServiceURL, cred, nil)
        if err != nil {
            log.Printf("Error creating table service client: %v", err)
            return err
        }
        client := stateTableClient.NewClient(stateTableName)

        partitionKey := monitoredQueueName // Use queue name as partition key
        rowKey := "latest"                 // Single row for simplicity

        var previousState StateEntity
        var previousDepth int32 = 0
        var lastCheckTime time.Time

        resp, err := client.GetEntity(ctx, partitionKey, rowKey, nil)
        if err == nil {
            err = json.Unmarshal(resp.Value, &previousState)
            if err == nil {
                previousDepth = previousState.LastDepth
                lastCheckTime = previousState.LastCheckTime
                log.Printf("Retrieved previous state: Depth=%d, Time=%s", previousDepth, lastCheckTime.Format(time.RFC3339))
            } else {
                log.Printf("Warn: Could not unmarshal previous state, assuming no prior state: %v", err)
            }
        } else {
            // Check if it's a "not found" error, which is fine for the first run
            var respErr *azcore.ResponseError
            if errors.As(err, &respErr) && respErr.StatusCode == http.StatusNotFound {
                log.Printf("No previous state found for %s (first run or state cleared).", monitoredQueueName)
            } else {
                log.Printf("Warn: Error getting previous state from table: %v. Proceeding without growth rate check.", err)
            }
        }

        // --- 4. Update State in Table Storage with current values ---
        newState := StateEntity{
            Entity: aztables.Entity{
                PartitionKey: partitionKey,
                RowKey:       rowKey,
            },
            LastDepth:     currentDepth,
            LastCheckTime: time.Now().UTC(),
        }
        stateJSON, _ := json.Marshal(newState)
        _, err = client.UpsertEntity(ctx, stateJSON, nil) // Upsert: updates if exists, inserts if not
        if err != nil {
            log.Printf("Error upserting state to table: %v", err)
            // Non-fatal, continue check but growth rate might be affected next run
        } else {
            log.Println("Successfully updated state in table storage.")
        }

        // --- 5. Check Depth Threshold ---
        if currentDepth <= int32(depthThreshold) {
            log.Printf("Depth %d is not above threshold %d. No action.", currentDepth, depthThreshold)
            return nil
        }
        log.Printf("Depth %d IS ABOVE threshold %d.", currentDepth, depthThreshold)

        // --- 6. Check Growth Rate ---
        // Only calculate growth if we have a valid previous state and enough time has passed
        timeSinceLastCheck := time.Now().UTC().Sub(lastCheckTime)
        if previousDepth > 0 && !lastCheckTime.IsZero() && timeSinceLastCheck.Seconds() >= float64(growthCheckIntervalSeconds) {
            depthIncrease := currentDepth - previousDepth
            var currentGrowthRatePercent float64 = 0
            if previousDepth > 0 { // Avoid division by zero
                currentGrowthRatePercent = (float64(depthIncrease) / float64(previousDepth)) * 100
            } else if currentDepth > 0 { // If previous was 0 and current is >0, growth is "infinite" or 100% from 0
                currentGrowthRatePercent = 100.0 // Or a very large number to signify significant growth
            }

            log.Printf("Growth check: PreviousDepth=%d, CurrentDepth=%d, Increase=%d, TimeSinceLastCheck=%.2fs",
                previousDepth, currentDepth, depthIncrease, timeSinceLastCheck.Seconds())
            log.Printf("Calculated growth rate: %.2f%%", currentGrowthRatePercent)

            if currentGrowthRatePercent <= growthRateThresholdPercent {
                log.Printf("Growth rate %.2f%% is not above threshold %.2f%%. No action.", currentGrowthRatePercent, growthRateThresholdPercent)
                return nil
            }
            log.Printf("Growth rate %.2f%% IS ABOVE threshold %.2f%%.", currentGrowthRatePercent, growthRateThresholdPercent)
        } else {
            log.Printf("Skipping growth rate check: Not enough data or time since last check (%.2fs < %ds). Threshold met, calling scaler.", timeSinceLastCheck.Seconds(), growthCheckIntervalSeconds)
            // If only depth threshold is met, and not enough time for growth rate, we can still decide to scale
            // This part of the logic is up to you. For this example, if depth is high, we trigger.
            // To be stricter, you might `return nil` here if a growth rate calculation wasn't possible.
        }

        // --- 7. Call Scaler Function ---
        log.Printf("Conditions met. Calling scaler function: %s", scalerFunctionURL)

        // Prepare request body for the scaler function (optional, if scaler needs info)
        // scalerPayload := map[string]string{"queueName": monitoredQueueName, "currentDepth": strconv.Itoa(int(currentDepth))}
        // payloadBytes, _ := json.Marshal(scalerPayload)
        // req, err := http.NewRequestWithContext(ctx, "POST", scalerFunctionURL, bytes.NewBuffer(payloadBytes))

        req, err := http.NewRequestWithContext(ctx, "POST", scalerFunctionURL, nil) // No body needed for this example
        if err != nil {
            log.Printf("Error creating request to scaler function: %v", err)
            return err
        }
        req.Header.Set("Content-Type", "application/json")
        if scalerFunctionKey != "" {
            req.Header.Set("x-functions-key", scalerFunctionKey)
        }

        httpClient := &http.Client{Timeout: 30 * time.Second}
        respScaler, err := httpClient.Do(req)
        if err != nil {
            log.Printf("Error calling scaler function: %v", err)
            return err
        }
        defer respScaler.Body.Close()

        if respScaler.StatusCode >= 200 && respScaler.StatusCode < 300 {
            log.Printf("Scaler function called successfully. Status: %s", respScaler.Status)
        } else {
            log.Printf("Scaler function call failed. Status: %s", respScaler.Status)
            // Potentially read response body for more details
            // bodyBytes, _ := io.ReadAll(respScaler.Body)
            // log.Printf("Scaler response body: %s", string(bodyBytes))
            return fmt.Errorf("scaler function call failed with status %s", respScaler.Status)
        }

        return nil
    }

    // Main registers the function (for Azure Functions Go worker)
    func main() {
        // The Go Functions worker looks for functions based on the directory name
        // or explicit registration if you have a custom setup.
        // For a simple setup where `handler.go` is in the root and `function.json`
        // points to `../handler.go` and the function directory is `check_sa_queue`,
        // the worker will find `CheckSaQueue`.
        // No explicit registration is needed here if using `func host start`.
    }

    ```
    Note: You will need `go get` for the Azure SDKs:
    ```bash
    cd check_sa_queue_project
    go get github.com/Azure/azure-sdk-for-go/sdk/azidentity
    go get github.com/Azure/azure-sdk-for-go/sdk/storage/azqueue
    go get github.com/Azure/azure-sdk-for-go/sdk/data/aztables
    go get github.com/Azure/azure-sdk-for-go/sdk/azcore
    go mod tidy
    ```

3.  **Modify `host.json` in `check_sa_queue_project` root:**
    Add logging configuration and specify Go handler.
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
          "default": "Information", // Or "Debug" for more verbose logs
          "Host.Results": "Information",
          "Function": "Information",
          "Host.Aggregator": "Information"
        }
      },
      "customHandler": {
        "description": {
          "defaultExecutablePath": "handler", // Name of the compiled Go binary
          "workingDirectory": "",
          "arguments": []
        },
        "enableForwardingHttpRequest": false // True if you were directly handling HTTP requests in Go
      },
      "managedDependency": {
        "enabled": true
      },
      "extensionBundle": {
        "id": "Microsoft.Azure.Functions.ExtensionBundle",
        "version": "[3.*, 4.0.0)" // Or a more recent compatible version
      }
    }
    ```
    **Important:** For Go custom handlers, you need to compile your `handler.go` to an executable. If your `handler.go` is in the root and your `host.json`'s `defaultExecutablePath` is `handler`, you'd compile it as:
    `GOOS=linux GOARCH=amd64 go build -o handler handler.go` (from project root)

---

**Step 5: Develop the `increase_hpa_aks` Azure Function (Go)**

1.  **Initialize Function Project:**
    ```bash
    mkdir increase_hpa_aks_project && cd increase_hpa_aks_project
    func init --worker-runtime go
    func new --name increase_hpa_aks --template "HTTP trigger"
    ```
    Edit `increase_hpa_aks/function.json`:
    ```json
    {
      "bindings": [
        {
          "authLevel": "function", // Use "function" for key-based auth, or "anonymous" if secured otherwise
          "type": "httpTrigger",
          "direction": "in",
          "name": "req",
          "methods": [
            "post"
          ]
        },
        {
          "type": "http",
          "direction": "out",
          "name": "res"
        }
      ],
      "scriptFile": "../handler.go"
    }
    ```

2.  **Create `handler.go` in `increase_hpa_aks_project` root:**
    ```go
    package main

    import (
        "context"
        "fmt"
        "log"
        "net/http"
        "os"
        "strconv"
        "time"

        "github.com/Azure/azure-sdk-for-go/sdk/azidentity"
        "github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservice/armcontainerservice"

        v2 "k8s.io/api/autoscaling/v2" // Correct import for HPA v2
        metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
        "k8s.io/client-go/kubernetes"
        "k8s.io/client-go/rest"
        // Required for AKS authentication
        _ "k8s.io/client-go/plugin/pkg/client/auth/azure"
    )

    // HTTPRequest is a placeholder for Azure Functions Go HTTP request binding
    type HTTPRequest struct {
        Method  string
        URL     string
        Headers map[string][]string
        Params  map[string]string
        Query   map[string]string
        Body    string
    }

    // HTTPResponse is a placeholder for Azure Functions Go HTTP response binding
    type HTTPResponse struct {
        Body       string
        StatusCode int
        Headers    map[string]string
    }

    // IncreaseHpaAks is the main function logic
    func IncreaseHpaAks(req HTTPRequest, log *log.Logger) HTTPResponse {
        log.Println("increase_hpa_aks function triggered.")

        aksResourceGroup := os.Getenv("AKS_RESOURCE_GROUP")
        aksClusterName := os.Getenv("AKS_CLUSTER_NAME")
        targetHpaName := os.Getenv("TARGET_HPA_NAME")
        targetHpaNamespace := os.Getenv("TARGET_HPA_NAMESPACE")
        increaseMaxByStr := os.Getenv("INCREASE_MAX_BY_COUNT") // How many to add to maxReplicas

        if aksResourceGroup == "" || aksClusterName == "" || targetHpaName == "" || targetHpaNamespace == "" || increaseMaxByStr == "" {
            log.Println("Error: Missing one or more required environment variables for HPA scaling.")
            return HTTPResponse{
                Body:       "Error: Missing environment variables.",
                StatusCode: http.StatusBadRequest,
            }
        }

        increaseMaxBy, err := strconv.Atoi(increaseMaxByStr)
        if err != nil || increaseMaxBy <= 0 {
            log.Printf("Error: Invalid INCREASE_MAX_BY_COUNT value: %s. Must be a positive integer.", increaseMaxByStr)
            return HTTPResponse{
                Body:       fmt.Sprintf("Error: Invalid INCREASE_MAX_BY_COUNT: %v", err),
                StatusCode: http.StatusBadRequest,
            }
        }

        // --- 1. Get Azure Credentials using Managed Identity ---
        cred, err := azidentity.NewDefaultAzureCredential(nil)
        if err != nil {
            log.Printf("Error creating default Azure credential: %v", err)
            return HTTPResponse{Body: "Error creating Azure credential.", StatusCode: http.StatusInternalServerError}
        }

        subscriptionID := os.Getenv("AZURE_SUBSCRIPTION_ID") // Will be set by Azure Function environment
        if subscriptionID == "" {
            log.Println("Error: AZURE_SUBSCRIPTION_ID environment variable not set.")
            // You might need to fetch it if not automatically populated in your Function App environment
            // For system-assigned MI, it usually is.
            return HTTPResponse{Body: "Error: AZURE_SUBSCRIPTION_ID not found.", StatusCode: http.StatusInternalServerError}
        }


        // --- 2. Get AKS Admin Kubeconfig ---
        aksClient, err := armcontainerservice.NewManagedClustersClient(subscriptionID, cred, nil)
        if err != nil {
            log.Printf("Error creating AKS client: %v", err)
            return HTTPResponse{Body: "Error creating AKS client.", StatusCode: http.StatusInternalServerError}
        }

        // Get admin credentials to interact with the cluster's K8s API
        // For user-level access, use `ListClusterUserCredentials`
        // For admin-level (needed to patch HPA typically), use `ListClusterAdminCredentials`
        // This requires the MI to have "Azure Kubernetes Service Cluster Admin Role"
        ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
        defer cancel()

        creds, err := aksClient.ListClusterAdminCredentials(ctx, aksResourceGroup, aksClusterName, nil)
        if err != nil {
            log.Printf("Error getting AKS admin credentials for %s: %v", aksClusterName, err)
            return HTTPResponse{Body: "Error getting AKS admin credentials.", StatusCode: http.StatusInternalServerError}
        }

        if len(creds.Kubeconfigs) == 0 {
            log.Printf("No kubeconfigs returned for AKS cluster %s", aksClusterName)
            return HTTPResponse{Body: "No kubeconfigs found for AKS.", StatusCode: http.StatusInternalServerError}
        }
        kubeconfigBytes := creds.Kubeconfigs[0].Value // Get the first kubeconfig

        // --- 3. Create Kubernetes Client from Kubeconfig ---
        // Create a REST config from the kubeconfig bytes
        config, err := clientcmd.RESTConfigFromKubeConfig(kubeconfigBytes)
        if err != nil {
            log.Printf("Error creating REST config from kubeconfig: %v", err)
            return HTTPResponse{Body: "Error creating K8s REST config.", StatusCode: http.StatusInternalServerError}
        }

        // Create Kubernetes clientset
        clientset, err := kubernetes.NewForConfig(config)
        if err != nil {
            log.Printf("Error creating Kubernetes clientset: %v", err)
            return HTTPResponse{Body: "Error creating K8s clientset.", StatusCode: http.StatusInternalServerError}
        }

        // --- 4. Get and Patch HPA ---
        hpaClient := clientset.AutoscalingV2().HorizontalPodAutoscalers(targetHpaNamespace)
        hpa, err := hpaClient.Get(ctx, targetHpaName, metav1.GetOptions{})
        if err != nil {
            log.Printf("Error getting HPA %s in namespace %s: %v", targetHpaName, targetHpaNamespace, err)
            return HTTPResponse{Body: fmt.Sprintf("Error getting HPA: %v", err), StatusCode: http.StatusInternalServerError}
        }

        originalMaxReplicas := hpa.Spec.MaxReplicas
        newMaxReplicas := originalMaxReplicas + int32(increaseMaxBy)

        log.Printf("Current HPA '%s' MaxReplicas: %d. Attempting to set to: %d", targetHpaName, originalMaxReplicas, newMaxReplicas)

        hpa.Spec.MaxReplicas = newMaxReplicas

        _, err = hpaClient.Update(ctx, hpa, metav1.UpdateOptions{})
        if err != nil {
            log.Printf("Error updating HPA %s: %v", targetHpaName, err)
            return HTTPResponse{Body: fmt.Sprintf("Error updating HPA: %v", err), StatusCode: http.StatusInternalServerError}
        }

        log.Printf("Successfully updated HPA %s in namespace %s. MaxReplicas changed from %d to %d.",
            targetHpaName, targetHpaNamespace, originalMaxReplicas, newMaxReplicas)

        return HTTPResponse{
            Body:       fmt.Sprintf("Successfully updated HPA %s. New MaxReplicas: %d", targetHpaName, newMaxReplicas),
            StatusCode: http.StatusOK,
        }
    }

    // Main for Azure Functions Go worker
    func main() {
        // Similar to the other function, explicit registration isn't strictly needed
        // if the function directory name matches the function name in Go.
    }
    ```
    You will need `go get` for these packages:
    ```bash
    cd increase_hpa_aks_project
    go get github.com/Azure/azure-sdk-for-go/sdk/azidentity
    go get github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/containerservice/armcontainerservice
    go get k8s.io/api/autoscaling/v2
    go get k8s.io/apimachinery/pkg/apis/meta/v1
    go get k8s.io/client-go/kubernetes
    go get k8s.io/client-go/tools/clientcmd
    go get k8s.io/client-go/plugin/pkg/client/auth/azure // For AKS auth provider
    go mod tidy
    ```

3.  **Modify `host.json` in `increase_hpa_aks_project` root:**
    Same as for `check_sa_queue_project`, ensure `customHandler` and `logging` are set up.
    `GOOS=linux GOARCH=amd64 go build -o handler handler.go` (from project root)

---

**Step 6: Configure Application Settings for Both Function Apps**

Go to the Azure portal, find your Function Apps (`$FUNCTION_APP_CHECK_NAME` and `$FUNCTION_APP_SCALE_NAME`). Under "Settings" -> "Configuration" -> "Application settings":

**For `checksaqueuefuncapp` (`$FUNCTION_APP_CHECK_NAME`):**
*   `MONITORED_STORAGE_ACCOUNT_NAME`: `YOUR_STORAGE_ACCOUNT_NAME` (the one with the queue to monitor)
*   `MONITORED_QUEUE_NAME`: `YOUR_QUEUE_NAME`
*   `DEPTH_THRESHOLD`: e.g., `100`
*   `GROWTH_RATE_THRESHOLD_PERCENT`: e.g., `50` (for 50% growth)
*   `GROWTH_CHECK_INTERVAL_SECONDS`: e.g., `300` (5 minutes - should be longer than function execution frequency)
*   `SCALER_FUNCTION_URL`: The URL of the `increase_hpa_aks` function. Get this from the `increase_hpa_aks` function's overview page or "Functions" blade ("Get Function URL").
*   `SCALER_FUNCTION_KEY`: (Optional) The function key for `increase_hpa_aks` if `authLevel` is `function`. Get this from "App keys" or "Function keys" in the `increase_hpa_aks` Function App.
*   `STATE_STORAGE_ACCOUNT_NAME`: Name of the storage account used by `checksaqueuefuncapp` itself (e.g., `$STORAGE_ACCOUNT_FUNC_CHECK` you created).
*   `STATE_TABLE_NAME`: `queuestatestore` (or the name you used when creating the table).
*   `AZURE_CLIENT_ID`: (Usually not needed for System MI, but if `DefaultAzureCredential` has issues, you might set this to the MI's Application (Client) ID. `DefaultAzureCredential` should find it automatically).
*   `FUNCTIONS_WORKER_RUNTIME`: `go` (This should have been set during creation)

**For `increasehpafuncapp` (`$FUNCTION_APP_SCALE_NAME`):**
*   `AKS_RESOURCE_GROUP`: `rg-cds-optmz-dev`
*   `AKS_CLUSTER_NAME`: `cdsaksclusterdev`
*   `TARGET_HPA_NAME`: `YOUR_HPA_NAME` (The name of the HPA object in your AKS cluster)
*   `TARGET_HPA_NAMESPACE`: `YOUR_HPA_NAMESPACE` (e.g., `default` or where your HPA resides)
*   `INCREASE_MAX_BY_COUNT`: e.g., `2` (Number of pods to increase `maxReplicas` by each time)
*   `AZURE_SUBSCRIPTION_ID`: Your Azure Subscription ID. This is often automatically available to the function environment when using managed identity. If not, add it.
*   `AZURE_CLIENT_ID`: (Same as above, usually not needed for System MI).
*   `FUNCTIONS_WORKER_RUNTIME`: `go`

---

**Step 7: Build and Deploy the Functions**

For each project (`check_sa_queue_project` and `increase_hpa_aks_project`):

1.  **Build the Go executable:**
    Navigate to the project root (e.g., `cd check_sa_queue_project`).
    ```bash
    # For check_sa_queue_project
    GOOS=linux GOARCH=amd64 go build -o handler handler.go

    # For increase_hpa_aks_project
    GOOS=linux GOARCH=amd64 go build -o handler handler.go
    ```
    This creates a Linux executable named `handler` in the project root.

2.  **Deploy using Azure Functions Core Tools:**
    Ensure you are in the project directory.
    ```bash
    # In check_sa_queue_project directory
    func azure functionapp publish $FUNCTION_APP_CHECK_NAME --custom # --custom for compiled binaries

    # In increase_hpa_aks_project directory
    func azure functionapp publish $FUNCTION_APP_SCALE_NAME --custom
    ```
    Using `--custom` tells the tools to deploy the already built binary specified in `host.json`.
    Alternatively, you can zip the contents (including `handler` executable, `host.json`, and the function folder like `check_sa_queue/function.json`) and deploy via "zip push":
    ```bash
    # Example for check_sa_queue_project:
    # zip -r ../check_sa_queue.zip ./* ./check_sa_queue/*
    # az functionapp deployment source config-zip -g $RESOURCE_GROUP -n $FUNCTION_APP_CHECK_NAME --src ../check_sa_queue.zip
    ```

---

**Step 8: Test and Monitor**

1.  **`check_sa_queue`:**
    *   Check its logs in Azure Portal (Monitor -> Logs or Application Insights).
    *   It should run on schedule.
    *   Verify it reads queue depth and writes state to `queuestatestore` table in `$STORAGE_ACCOUNT_FUNC_CHECK`.
    *   Add messages to `YOUR_QUEUE_NAME` in `YOUR_STORAGE_ACCOUNT_NAME` to exceed the threshold.
    *   Verify it attempts to call the `increase_hpa_aks` function.

2.  **`increase_hpa_aks`:**
    *   Trigger it manually (e.g., with Postman or curl, using its function URL and key) or let `check_sa_queue` trigger it.
    *   Check its logs.
    *   Verify in AKS (`kubectl get hpa YOUR_HPA_NAME -n YOUR_HPA_NAMESPACE -o yaml`) that `maxReplicas` has increased.

**Important Considerations and Best Practices:**

*   **KEDA (Kubernetes Event-driven Autoscaling):** For scaling AKS pods based on Azure Queue depth, **KEDA is the idiomatic and generally recommended solution**. It runs within your AKS cluster and can directly scale deployments based on queue length without needing external Azure Functions to mediate. Consider if KEDA meets your needs directly, as it simplifies this specific scaling pattern. The solution above is a custom implementation of what KEDA offers for Azure Queues.
    *   KEDA: [https://keda.sh/](https://keda.sh/)
    *   KEDA Azure Queue Scaler: [https://keda.sh/docs/scalers/azure-storage-queue/](https://keda.sh/docs/scalers/azure-storage-queue/)
*   **Error Handling & Retries:** The provided code has basic error handling. Implement more robust retry mechanisms, especially for the HTTP call to the scaler function and for Kubernetes API interactions.
*   **Security:**
    *   The HTTP trigger for `increase_hpa_aks` is set to `function` level auth. This is decent for internal calls. For higher security, consider AAD authentication between the functions if they are in the same tenant.
    *   Least Privilege: Review the IAM roles. "Azure Kubernetes Service Cluster Admin Role" is very permissive. If possible, scope down permissions within AKS using Kubernetes RBAC for the Managed Identity of `increasehpafuncapp`.
*   **Idempotency:** The `increase_hpa_aks` function as written isn't strictly idempotent for `maxReplicas` (it always adds). You might want to add logic to check if `maxReplicas` is already at a desired cap or if a recent scaling action occurred.
*   **Cool-down Periods:** Implement cool-down periods after scaling actions to prevent flapping (rapid scale-up/scale-down). The HPA itself has stabilization windows, but your custom logic might also benefit from this.
*   **Configuration Management:** Keep sensitive values like function keys in Azure Key Vault and reference them in App Settings.
*   **Logging and Monitoring:** Leverage Application Insights extensively for both functions to track their execution, errors, and performance.
*   **State Management for `check_sa_queue`:** Azure Table Storage is good for this. Ensure your partition key and row key strategy is efficient if you monitor many queues. For a single queue, the `QueueName` as PartitionKey and a static RowKey like `"latest"` is fine.
*   **Maximum `maxReplicas`:** Consider adding a safeguard in `increase_hpa_aks` to not increase `maxReplicas` beyond a predefined absolute maximum to prevent runaway scaling.

This comprehensive guide should allow you to build, deploy, and configure these two Azure Functions. Remember to replace placeholders with your actual resource names and desired thresholds.
