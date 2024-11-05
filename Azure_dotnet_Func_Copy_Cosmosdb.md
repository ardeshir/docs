# C# Azure functions, one to copy Cosmosdb

To achieve this, you'll need two Azure Functions: one for exporting data from a Cosmos DB in the production environment to a storage account, and another for importing data from the storage account into a Cosmos DB in the development environment. Below, I provide the architectural requirements and the C# code for both Azure Functions.

### Architectural Requirements
 

1. Azure Function App in Production:
- Trigger: Timer Trigger (e.g., daily, weekly)
- Output: Azure Blob Storage (JSON files)
- Dependencies: Azure Cosmos DB SDK, Azure Storage SDK
2. Azure Function App in Development:
- Trigger: Blob Trigger (when a new JSON file is uploaded to the storage account)
- Output: Azure Cosmos DB
- Dependencies: Azure Cosmos DB SDK, Azure Storage SDK

### Best Practices

1. Security:
- Use Managed Identity or secure service principals to access Azure resources.
- Store sensitive configurations in Azure Key Vault.
2. Performance:
- Paginate Cosmos DB queries to handle large datasets efficiently.
- Batch write operations to Cosmos DB for better performance.
3. Error Handling:
- Implement robust error handling and logging.
- Use retry policies for transient failures.
4. Configuration:
- Use app settings and configurations instead of hardcoding values.

### Azure Function to Export Data from Cosmos DB to Blob Storage
 
First, create a new Azure Function with a Timer Trigger. This function will query the Cosmos DB and write the results to an Azure Blob Storage container.

#### FunctionApp1/ExportCosmosDbToBlob.cs

```csharp
using System;  
using System.IO;  
using System.Linq;  
using System.Text;  
using System.Threading.Tasks;  
using Microsoft.Azure.Cosmos;  
using Microsoft.Azure.WebJobs;  
using Microsoft.Extensions.Logging;  
using Microsoft.WindowsAzure.Storage;  
using Microsoft.WindowsAzure.Storage.Blob;  
  
public static class ExportCosmosDbToBlob  
{  
    private static readonly string cosmosEndpointUri = Environment.GetEnvironmentVariable("CosmosEndpointUri");  
    private static readonly string cosmosPrimaryKey = Environment.GetEnvironmentVariable("CosmosPrimaryKey");  
    private static readonly string databaseId = Environment.GetEnvironmentVariable("CosmosDatabaseId");  
    private static readonly string containerId = Environment.GetEnvironmentVariable("CosmosContainerId");  
    private static readonly string storageConnectionString = Environment.GetEnvironmentVariable("StorageConnectionString");  
    private static readonly string containerName = Environment.GetEnvironmentVariable("BlobContainerName");  
  
    [FunctionName("ExportCosmosDbToBlob")]  
    public static async Task Run([TimerTrigger("0 0 0 * * *")] TimerInfo myTimer, ILogger log)  
    {  
        log.LogInformation($"ExportCosmosDbToBlob function executed at: {DateTime.Now}");  
  
        CosmosClient cosmosClient = new CosmosClient(cosmosEndpointUri, cosmosPrimaryKey);  
        Container cosmosContainer = cosmosClient.GetContainer(databaseId, containerId);  
  
        // Query Cosmos DB  
        var query = cosmosContainer.GetItemQueryIterator<dynamic>("SELECT * FROM c");  
        var results = await query.ReadNextAsync();  
  
        // Serialize results to JSON  
        string jsonData = System.Text.Json.JsonSerializer.Serialize(results.ToList());  
  
        // Upload JSON to Blob Storage  
        CloudStorageAccount storageAccount = CloudStorageAccount.Parse(storageConnectionString);  
        CloudBlobClient blobClient = storageAccount.CreateCloudBlobClient();  
        CloudBlobContainer blobContainer = blobClient.GetContainerReference(containerName);  
  
        string blobName = $"backup_{DateTime.UtcNow:yyyyMMddHHmmss}.json";  
        CloudBlockBlob blockBlob = blobContainer.GetBlockBlobReference(blobName);  
  
        using (var stream = new MemoryStream(Encoding.UTF8.GetBytes(jsonData)))  
        {  
            await blockBlob.UploadFromStreamAsync(stream);  
        }  
  
        log.LogInformation($"Data exported to blob {blobName}");  
    }  
}  
```

### Azure Function to Import Data from Blob
Let's create the Azure Function that will import data from the Blob Storage into the Cosmos DB in the development environment. This function will be triggered when a new JSON file is uploaded to the specified Blob Storage container.

- FunctionApp2/ImportBlobToCosmosDb.cs 

```csharp 
using System;  
using System.IO;  
using System.Threading.Tasks;  
using Microsoft.Azure.Cosmos;  
using Microsoft.Azure.WebJobs;  
using Microsoft.Extensions.Logging;  
using Microsoft.WindowsAzure.Storage;  
using Microsoft.WindowsAzure.Storage.Blob;  
  
public static class ImportBlobToCosmosDb  
{  
    private static readonly string cosmosEndpointUri = Environment.GetEnvironmentVariable("DevCosmosEndpointUri");  
    private static readonly string cosmosPrimaryKey = Environment.GetEnvironmentVariable("DevCosmosPrimaryKey");  
    private static readonly string databaseId = Environment.GetEnvironmentVariable("DevCosmosDatabaseId");  
    private static readonly string containerId = Environment.GetEnvironmentVariable("DevCosmosContainerId");  
  
    [FunctionName("ImportBlobToCosmosDb")]  
    public static async Task Run([BlobTrigger("backups/{name}", Connection = "StorageConnectionString")] Stream blobStream, string name, ILogger log)  
    {  
        log.LogInformation($"ImportBlobToCosmosDb function processed blob\n Name:{name} \n Size: {blobStream.Length} Bytes");  
  
        CosmosClient cosmosClient = new CosmosClient(cosmosEndpointUri, cosmosPrimaryKey);  
        Container cosmosContainer = cosmosClient.GetContainer(databaseId, containerId);  
  
        using (var reader = new StreamReader(blobStream))  
        {  
            string jsonData = await reader.ReadToEndAsync();  
            var items = System.Text.Json.JsonSerializer.Deserialize<dynamic[]>(jsonData);  
  
            foreach (var item in items)  
            {  
                try  
                {  
                    await cosmosContainer.CreateItemAsync(item);  
                }  
                catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.Conflict)  
                {  
                    log.LogWarning($"Item with id {item.id} already exists");  
                }  
                catch (Exception ex)  
                {  
                    log.LogError($"Error inserting item: {ex.Message}");  
                }  
            }  
        }  
  
        log.LogInformation("Data import completed");  
    }  
}  

```

### Explanation of the Code
 
1. BlobTrigger:
- The function is triggered when a new file is added to the Blob Storage container named backups.
- The connection string for the storage account is read from the environment variable StorageConnectionString.
2. Cosmos DB Connection:
- The Cosmos DB client is initialized using the endpoint URI and primary key from the environment variables.
- The target Cosmos DB container is specified.
3.  Reading and Deserializing JSON:
- The blob content is read into a string.
- The JSON string is deserialized into a dynamic array.
4. Inserting Items into Cosmos DB:
- Each item is inserted into the Cosmos DB container.
- Error handling is provided to log warnings for conflicts (i.e., items with the same ID already exist) and to log errors for other exceptions.

### Best Practices
 

1. Security:
- Ensure that the connection strings and other sensitive information are stored securely in Azure Key Vault or in the application settings with proper access controls.
2. Performance:
- For large datasets, consider implementing pagination and batching of write operations to avoid hitting request limits and to improve performance.
3. Error Handling:
- Implement robust error handling and logging to track and troubleshoot issues effectively.
- Use retry policies to handle transient failures when interacting with Azure services.
4. Configuration:
- Avoid hardcoding values. Use environment variables or configuration files to manage settings.
5. Monitoring and Logging:
- Use Azure Application Insights for monitoring and logging to gain insights into function executions and performance. 


# step-by-step instructions to create, structure, and deploy the two Azure Functions using the .NET CLI

### Step 1: Create the Azure function projects

1. Open a terminal or command prompt.
2. Create a directory for your projects: 

```bash
mkdir AzureFunctionsProject  
cd AzureFunctionsProject  
```

3. Create the first function app for exporting data:

```bash   
dotnet new func --name ExportFunctionApp  
cd ExportFunctionApp  
```  

4. Create the Timer Trigger function:

```bash  
dotnet new timer --name ExportCosmosDbToBlob --schedule "0 0 0 * * *"  
```  

5. Go back to the root directory:
```bash  
cd ..  
```  
6. Create the second function app for importing data:
```bash  
dotnet new func --name ImportFunctionApp  
cd ImportFunctionApp  
```  
7. Create the Blob Trigger function:
```bash  
dotnet new blob --name ImportBlobToCosmosDb --connection "StorageConnectionString" --path "backups/{name}"  
```  

### Step 2: Install Required Packages

1. For the ExportFunctionApp, install the required packages:
- cd ExportFunctionApp  
- dotnet add package Microsoft.Azure.Cosmos  
- dotnet add package WindowsAzure.Storage  

2. For the ImportFunctionApp, install the required packages:
```bash  
cd ..  
cd ImportFunctionApp  
dotnet add package Microsoft.Azure.Cosmos  
dotnet add package WindowsAzure.Storage  
```  

### Step 3: Implement the Functions 

1. ExportFunctionApp/ExportCosmosDbToBlob.cs:

- Replace the content of ExportFunctionApp/ExportCosmosDbToBlob.cs with the previously provided code.

2. ImportFunctionApp/ImportBlobToCosmosDb.cs:

- Replace the content of ImportFunctionApp/ImportBlobToCosmosDb.cs with the previously provided code.

### Step 4: Set Up Configuration

1. Add the necessary configurations to the local.settings.json file in each project directory.

- ExportFunctionApp/local.settings.json: 

```json
{  
  "IsEncrypted": false,  
  "Values": {  
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",  
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",  
    "CosmosEndpointUri": "your-cosmos-endpoint-uri",  
    "CosmosPrimaryKey": "your-cosmos-primary-key",  
    "CosmosDatabaseId": "your-cosmos-database-id",  
    "CosmosContainerId": "your-cosmos-container-id",  
    "StorageConnectionString": "your-storage-connection-string",  
    "BlobContainerName": "your-blob-container-name"  
  }  
}  
```
- ImportFunctionApp/local.settings.json:

```json 
{  
  "IsEncrypted": false,  
  "Values": {  
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",  
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",  
    "DevCosmosEndpointUri": "your-dev-cosmos-endpoint-uri",  
    "DevCosmosPrimaryKey": "your-dev-cosmos-primary-key",  
    "DevCosmosDatabaseId": "your-dev-cosmos-database-id",  
    "DevCosmosContainerId": "your-dev-cosmos-container-id",  
    "StorageConnectionString": "your-storage-connection-string"  
  }  
}  
```

### Step 5: Deploy the Azure Functions (continued)

1. Login to Azure
 - az login 

2. Create a Resource group (if you don't already have one)  
```bash  
az group create --name MyResourceGroup --location <location>  
```

3. Create a storage account (if you don't already have one):
```bash  
az storage account create --name mystorageaccount --location <location> --resource-group MyResourceGroup --sku Standard_LRS  
```  

4. Create a function app for the export function:
```bash  
az functionapp create --resource-group MyResourceGroup --consumption-plan-location <location> --runtime dotnet --functions-version 3 --name ExportFunctionApp --storage-account mystorageaccount  
```  

5. Deploy the ExportFunctionApp:
```bash  
cd ExportFunctionApp  
func azure functionapp publish ExportFunctionApp  
cd ..  
```  

6. Create a function app for the import function:
```bash  
az functionapp create --resource-group MyResourceGroup --consumption-plan-location <location> --runtime dotnet --functions-version 3 --name ImportFunctionApp --storage-account mystorageaccount  
```  

7. Deploy the ImportFunctionApp:
```bash  
cd ImportFunctionApp  
func azure functionapp publish ImportFunctionApp  
```  

### Step 6: Verify and Test the Deployment

1. Verify Export Function Deployment:
- Go to the Azure portal.
- Navigate to the resource group MyResourceGroup.
- Select ExportFunctionApp.
- In the Functions section, verify that ExportCosmosDbToBlob function is listed and has a timer trigger configured.
2. Verify Import Function Deployment:
- Navigate to the resource group MyResourceGroup.
- Select ImportFunctionApp.
- In the Functions section, verify that ImportBlobToCosmosDb function is listed and has a blob trigger configured.
3. Test the Functions:
- For the export function, manually trigger the timer function to export data to the blob storage. This can be done by adjusting the schedule in the local.settings.json to a more frequent interval for testing.
- Upload a sample JSON file to the blob container specified in local.settings.json for the import function and verify if it is imported correctly into the Cosmos DB in the development environment.

#### Summary
 
By following the above steps, you will have successfully created, configured, and deployed two Azure Functions that handle exporting data from a Cosmos DB in the production environment to Azure Blob Storage, and importing that data into a Cosmos DB in the development environment. The process includes setting up the necessary infrastructure, coding the functions, configuring settings, and deploying the solutions to Azure. This ensures a smooth and secure data transfer process between environments.
