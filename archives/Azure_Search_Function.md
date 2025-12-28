# Azure Search Function Trigger reIndex 

Azure Cognitive Search (formerly known as Azure Search) is a search-as-a-service solution that allows developers to build robust search experiences into their applications. The fundamental technology behind Azure Cognitive Search includes:

1. Full-Text Search Engine: Azure Cognitive Search uses a full-text search engine to index and query text. It supports various text-processing capabilities such as tokenization, stemming and scoring. 
2. Indexing: The service can index data from various sources including Azure SQL Database, Azure Cosmos DB, and Azure Blob Storage. It supports multiple data types and complex data structures.
3. Scalability and Performance: Azure Cognitive Search scales out by partitioning indexes and replicating them for high availability and performance.
4. AI Enrichment: Built-in AI capabilities for cognitive skills, such as image and text analysis, can be used to extract additional information from the data.

#### Best Features of Azure Cognitive Search
 

1. Rich Query Language: Supports a variety of query types, including full-text search, filters, facets, and geospatial queries.
2. Synonyms and Analyzers: Customizable analyzers and synonym maps to improve search relevance.
3. Security: Role-based access control and data encryption in transit and at rest.
4. AI Enrichment: Integration with Cognitive Services for enriching content during indexing.
5. Extensibility: Custom skills and knowledge store for extending search capabilities.
6. High Availability: Built-in redundancy and failover capabilities.

#### Building a Robust, Scalable, Cross-Regional Database-Driven Web Application
 
To build a robust, scalable, cross-regional database-driven web application using Azure Cognitive Search, follow these steps:

1. Set Up Azure Resources:
	- Create an Azure Cognitive Search Service.
	- Set up your data source (e.g., Azure SQL Database, Azure Cosmos DB).
	- Configure Azure Storage Accounts for queue storage if needed.
2. Index Data:
	- Define an index schema that fits your data model.
	- Create an index in Azure Cognitive Search.
	- Use data importers to pull data from your data source into the index.
3. Implement Azure Functions:
	- Set up Azure Functions to handle reindexing logic.
	- Trigger Azure Functions using Azure Queue Storage.

### Step-by-Step Guide to Reindex Using Azure Functions
 

#### Prerequisites: 
 

- Azure Subscription
- Azure Cognitive Search service created
- Azure Storage Account with Queue Storage
- Azure Functions App

#### Step 1: Create an Azure Function App
 1. Go to the Portal or use the Azure Func cli tool
 2. Create a function with your requirements 

#### Step 2: Create a Queue Storage Trigger Function
 

1. In the Azure portal, navigate to your Function App.
2. Click on "Functions" and then "Add".
3.  Choose "Queue trigger" and click "Create".

#### Step 3: Install Azure Cognitive Search Client Library
 
- Ensure you have the latest Azure Cognitive Search SDK installed. If you're using Visual Studio or any other IDE, install the NuGet package:

```bash 
dotnet add package Azure.Search.Documents  
``` 

#### Step 4: Implement the Function to Reindex Data (continued)

	- Open the ReindexFunction.cs file in your project and replace its contents with the following code. Ensure you have installed the Azure Cognitive Search SDK as mentioned earlier.
```csharp
using System;  
using System.Threading.Tasks;  
using Azure;  
using Azure.Search.Documents;  
using Azure.Search.Documents.Indexes;  
using Azure.Search.Documents.Indexes.Models;  
using Microsoft.Azure.WebJobs;  
using Microsoft.Extensions.Logging;  
  
public static class ReindexFunction  
{  
    private static readonly string searchServiceName = Environment.GetEnvironmentVariable("SearchServiceName");  
    private static readonly string apiKey = Environment.GetEnvironmentVariable("SearchApiKey");  
    private static readonly string indexName = Environment.GetEnvironmentVariable("IndexName");  
  
    [FunctionName("ReindexFunction")]  
    public static async Task Run(  
        [QueueTrigger("reindex-queue", Connection = "AzureWebJobsStorage")] string queueItem,  
        ILogger log)  
    {  
        log.LogInformation($"C# Queue trigger function processed: {queueItem}");  
  
        try  
        {  
            // Create a SearchIndexClient to manage the index  
            Uri serviceEndpoint = new Uri($"https://{searchServiceName}.search.windows.net");  
            AzureKeyCredential credential = new AzureKeyCredential(apiKey);  
            SearchIndexClient indexClient = new SearchIndexClient(serviceEndpoint, credential);  
  
            // Optionally, you can recreate the index schema if needed  
            // await CreateOrUpdateIndexAsync(indexClient, log);  
  
            // Create a SearchClient to upload documents to the index  
            SearchClient searchClient = indexClient.GetSearchClient(indexName);  
  
            // Here you can fetch data from your data source and convert it to the required format  
            var documents = FetchDocumentsForIndexing(queueItem, log);  
  
            // Upload the documents to the search index  
            await searchClient.UploadDocumentsAsync(documents);  
  
            log.LogInformation("Reindexing completed successfully.");  
        }  
        catch (Exception ex)  
        {  
            log.LogError($"Exception occurred while reindexing: {ex.Message}");  
        }  
    }  
  
    // Example method to fetch and prepare documents for indexing  
    private static object[] FetchDocumentsForIndexing(string queueItem, ILogger log)  
    {  
        // Replace this with actual logic to fetch and prepare your documents  
        log.LogInformation($"Fetching documents for queue item: {queueItem}");  
          
        // Dummy data for demonstration purposes  
        var documents = new[]  
        {  
            new { Id = "1", Name = "Sample Document 1", Description = "Description for document 1" },  
            new { Id = "2", Name = "Sample Document 2", Description = "Description for document 2" }  
        };  
          
        return documents;  
    }  
  
    // Optional: Method to create or update the index schema  
    private static async Task CreateOrUpdateIndexAsync(SearchIndexClient indexClient, ILogger log)  
    {  
        var fieldBuilder = new FieldBuilder();  
        var searchFields = fieldBuilder.Build(typeof(MyDocument));  
  
        var definition = new SearchIndex(indexName, searchFields);  
  
        // Create or update the index  
        await indexClient.CreateOrUpdateIndexAsync(definition);  
  
        log.LogInformation("Index schema created or updated successfully.");  
    }  
  
    // Define the document schema  
    private class MyDocument  
    {  
        [SimpleField(IsKey = true)]  
        public string Id { get; set; }  
  
        [SearchableField]  
        public string Name { get; set; }  
  
        [SearchableField]  
        public string Description { get; set; }  
    }  
}  
``` 

#### Step 5: Configure Environment Variables
 
Ensure that you have set the required environment variables in your Azure Function App settings:
 
To configure the environment variables for your Azure Function App, follow these steps:

1. Navigate to your Function App in the Azure Portal:
    - Go to the Azure portal.
    - Navigate to your Function App.
2. Add Application Settings:
    - In the left menu, under Settings, select Configuration.
    - Click on the + New application setting button and add the following settings:
        - SearchServiceName: The name of your Azure Cognitive Search service.
        - SearchApiKey: The admin key for your Azure Cognitive Search service.
        - IndexName: The name of the index you want to create or update.
        - AzureWebJobsStorage: The connection string for your Azure Storage account.

#### Step 6: Deploy and Test Your Function
 

1. Deploy the Function App:
    - You can deploy your Function App using various methods such as Visual Studio, Azure CLI, or through continuous integration/continuous deployment (CI/CD) pipelines.
    - For example, if using Visual Studio:
        - Right-click on the Function App project and select Publish.
        - Follow the prompts to publish your Function App to Azure.
2. Add a Message to the Queue:
    - Navigate to your Azure Storage Account in the Azure Portal.
    - Select Queues and then select your queue (e.g., reindex-queue).
    - Add a new message to the queue to trigger the function.
3. Monitor the Function Execution:
    - Go to the Monitor tab of your Function App in the Azure Portal.
    - Check the logs to ensure that the function executed successfully and that the reindexing process completed without errors.

### Complete Code Example for Reindex Function
 
Here is the complete code example for the Azure Function that reindexes data using a queue trigger:

```csharp 
using System;  
using System.Threading.Tasks;  
using Azure;  
using Azure.Search.Documents;  
using Azure.Search.Documents.Indexes;  
using Azure.Search.Documents.Indexes.Models;  
using Microsoft.Azure.WebJobs;  
using Microsoft.Extensions.Logging;  
  
public static class ReindexFunction  
{  
    private static readonly string searchServiceName = Environment.GetEnvironmentVariable("SearchServiceName");  
    private static readonly string apiKey = Environment.GetEnvironmentVariable("SearchApiKey");  
    private static readonly string indexName = Environment.GetEnvironmentVariable("IndexName");  
  
    [FunctionName("ReindexFunction")]  
    public static async Task Run(  
        [QueueTrigger("reindex-queue", Connection = "AzureWebJobsStorage")] string queueItem,  
        ILogger log)  
    {  
        log.LogInformation($"C# Queue trigger function processed: {queueItem}");  
  
        try  
        {  
            // Create a SearchIndexClient to manage the index  
            Uri serviceEndpoint = new Uri($"https://{searchServiceName}.search.windows.net");  
            AzureKeyCredential credential = new AzureKeyCredential(apiKey);  
            SearchIndexClient indexClient = new SearchIndexClient(serviceEndpoint, credential);  
  
            // Optionally, you can recreate the index schema if needed  
            // await CreateOrUpdateIndexAsync(indexClient, log);  
  
            // Create a SearchClient to upload documents to the index  
            SearchClient searchClient = indexClient.GetSearchClient(indexName);  
  
            // Here you can fetch data from your data source and convert it to the required format  
            var documents = FetchDocumentsForIndexing(queueItem, log);  
  
            // Upload the documents to the search index  
            await searchClient.UploadDocumentsAsync(documents);  
  
            log.LogInformation("Reindexing completed successfully.");  
        }  
        catch (Exception ex)  
        {  
            log.LogError($"Exception occurred while reindexing: {ex.Message}");  
        }  
    }  
  
    // Example method to fetch and prepare documents for indexing  
    private static object[] FetchDocumentsForIndexing(string queueItem, ILogger log)  
    {  
        // Replace this with actual logic to fetch and prepare your documents  
        log.LogInformation($"Fetching documents for queue item: {queueItem}");  
          
        // Dummy data for demonstration purposes  
        var documents = new[]  
        {  
            new { Id = "1", Name = "Sample Document 1", Description = "Description for document 1" },  
            new { Id = "2", Name = "Sample Document 2", Description = "Description for document 2" }  
        };  
          
        return documents;  
    }  
  
    // Optional: Method to create or update the index schema  
    private static async Task CreateOrUpdateIndexAsync(SearchIndexClient indexClient, ILogger log)  
    {  
        var fieldBuilder = new FieldBuilder();  
        var searchFields = fieldBuilder.Build(typeof(MyDocument));  
  
        var definition = new SearchIndex(indexName, searchFields);  
  
        // Create or update the index  
        await indexClient.CreateOrUpdateIndexAsync(definition);  
  
        log.LogInformation("Index schema created or updated successfully.");  
    }  
  
    // Define the document schema  
    private class MyDocument  
    {  
        [SimpleField(IsKey = true)]  
        public string Id { get; set; }  
  
        [SearchableField]  
        public string Name { get; set; }  
  
        [SearchableField]  
        public string Description { get; set; }  
    }  
}  
``` 

#### Step 7: Verify and Test the Solution
 
1. Deploy the Function App:
	- Use Visual Studio, Azure CLI, or any other deployment tool to deploy the function to Azure. If using Visual Studio:
	- Right-click on the Function App project and select Publish.
	- Follow the prompts to publish your Function App to Azure.
2. Add a Message to the Queue:
	- Navigate to the Azure Storage Account in the Azure Portal.
	- Go to Queues, select the queue named reindex-queue.
	- Add a new message to the queue. The content of the message can be any string that your FetchDocumentsForIndexing method can process (e.g., an identifier or a signal to trigger reindexing).
3. Monitor the Function Execution:
	- Go to the Monitor tab of your Function App in the Azure Portal.
	- Check the logs to ensure that the function executed successfully and that the reindexing process completed without errors. Look for log entries indicating the processing of the queue item and successful reindexing.
4. Verify the Indexed Data:
	- Navigate to your Azure Cognitive Search service in the Azure Portal.
	- Go to Indexes and select the index you specified (IndexName).
	- Use the Search explorer to query the index and verify that the documents were indexed correctly.

### References

- **Azure Cognitive Search Documentation**: Provides comprehensive details on setting up, configuring, and using various features of Azure Cognitive Search.
  [Azure Cognitive Search Documentation](https://learn.microsoft.com/azure/search/search-what-is-azure-search)