# CSharp Azure Function QueueChecker Trigger

### Step-by-step Guide:

1. **Create an Azure Storage Account and Queue:**
   - Ensure you have an Azure Storage account and a queue set up in Azure Storage. This is where the queue you want to monitor exists.

2. **Create an Azure Function App:**
   - In the Azure Portal, create a new Function App if you do not already have one.

3. **Choose the Development Environment:**
   - You can develop Azure Functions in several environments. Common choices are Visual Studio Code or the Azure Portal directly. For frequent development, using Visual Studio Code with Azure Functions extensions is recommended.

4. **Setup Your Function:**
   - Use an HTTP trigger or Timer trigger function based on your needs. In this case, a Timer trigger is appropriate:
   - Since you want the function to trigger every minute, set the timer to `0 */1 * * * *`.

5. **Add the Queue Storage NuGet package:**
   - If using C#, ensure your project file (`.csproj`) references the `Microsoft.Azure.Storage.Queue` NuGet package. You can add it via the Package Manager Console:
     ```shell
     Install-Package Microsoft.Azure.Storage.Queue
     ```

6. **Sample Function Code:**
   - The following is a basic example in C#. It checks the queue length and sends an HTTP POST if the length is above 50. Ensure you replace placeholders with your actual connection strings, URL, and queue names.

```csharp
using System;
using System.Net.Http;
using System.Text;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.Storage;
using Microsoft.Azure.Storage.Queue;
using Microsoft.Extensions.Logging;

public class CheckQueueFunction
{
    private static readonly HttpClient HttpClient = new HttpClient();

    [FunctionName("CheckQueueDepth")]
    public static async void Run([TimerTrigger("0 */1 * * * *")] TimerInfo myTimer, ILogger log)
    {
        string storageConnectionString = Environment.GetEnvironmentVariable("AzureWebJobsStorage");
        string queueName = "your-queue-name";
        var alertThreshold = 50;

        CloudStorageAccount storageAccount = CloudStorageAccount.Parse(storageConnectionString);
        CloudQueueClient queueClient = storageAccount.CreateCloudQueueClient();
        CloudQueue queue = queueClient.GetQueueReference(queueName);

        await queue.FetchAttributesAsync();
        int? messageCount = queue.ApproximateMessageCount;

        if (messageCount.HasValue)
        {
            log.LogInformation($"Queue length: {messageCount.Value}");
            // Check if over 50%
            if (messageCount.Value > alertThreshold)
            {
                var json = "{ \"body\": \"Alert > 50%\" }";
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                var response = await HttpClient.PostAsync("https://book.univrs.io/MarkD", content);

                if (response.IsSuccessStatusCode)
                {
                    log.LogInformation("Alert sent.");
                }
                else
                {
                    log.LogError($"Failed to send alert. Status Code: {response.StatusCode}");
                }
            }
        }
    }
}
```

7. **Configure Environment Variables:**
   - Ensure your function’s application settings in Azure include the `AzureWebJobsStorage` connection string for your storage account and any other configurations necessary.

8. **Deploy Your Function:**
   - Deploy your function using Azure Functions Core Tools (`func` CLI), Visual Studio Code, or directly from the Azure Portal.

9. **Monitor:**
   - Use the Azure Portal to monitor your function's execution and its log output to ensure it behaves as expected.

### Note:
- Ensure to handle potential exceptions (e.g., connection issues with storage or network failures during HTTP requests) in the actual implementation.
- Test the behavior thoroughly, especially with secured environments and networks (firewalls, API keys, etc.).

