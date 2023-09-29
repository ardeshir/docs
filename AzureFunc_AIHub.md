# Q: 
Write an Azure Function using CSharp C# 10 & .net6 that reads custom fields from Application Insights, and sends this to Azure Hub?

# A:
Azure Functions are a great way to process data. You can use them to pull data from Application Insights and send it to Azure Event Hubs. The following is an example of how you can do this.

First, you have to install the necessary packages:
Microsoft.Azure.WebJobs
Microsoft.Azure.WebJobs.Extensions.EventHubs
Microsoft.ApplicationInsights

Here is a simple Azure Function app written in C# that reads custom fields from Application Insights and sends this to Azure Event Hub:

```CSharp
using System;  
using System.Threading.Tasks;  
using Microsoft.ApplicationInsights;  
using Microsoft.ApplicationInsights.DataContracts;  
using Microsoft.ApplicationInsights.Extensibility;  
using Microsoft.Azure.WebJobs;  
using Microsoft.Azure.WebJobs.Host;  
using Microsoft.Extensions.Logging;  
  
public static class Function1  
{  
    private static TelemetryClient telemetryClient;  
  
    static Function1()  
    {  
        TelemetryConfiguration configuration = TelemetryConfiguration.CreateDefault();  
        configuration.InstrumentationKey = "your-instrumentation-key";  
        telemetryClient = new TelemetryClient(configuration);  
    }  
  
    [FunctionName("Function1")]  
    public static void Run([EventHubTrigger("samples-workitems", Connection = "EventHubConnectionAppSetting")]string myEventHubMessage, ILogger log)  
    {  
        log.LogInformation($"C# Event Hub trigger function processed a message: {myEventHubMessage}");  
          
        var telemetry = new EventTelemetry("Custom Event");  
        telemetry.Properties["Custom Field"] = myEventHubMessage;  
        telemetryClient.TrackEvent(telemetry);  
    }  
}  
``` 
## 
- dotnet add package Microsoft.Azure.WebJobs.Extensions.EventHubs --version 6.0.0
- dotnet add package Microsoft.Azure.Functions.Extensions --version 1.1.0
- dotnet add package Microsoft.ApplicationInsights --version 2.22.0-beta3
- dotnet add package Azure.ResourceManager.Monitor --version 1.3.0-beta.2
###
Replace "your-instrumentation-key" with your Application Insights instrumentation key.

## This function is triggered whenever a new message arrives at the specified Azure Event Hub. It reads the message, creates a new custom event telemetry with a custom field, and sends it to Application Insights.

## Please remember to replace "samples-workitems" with your Azure Event Hub name and "EventHubConnectionAppSetting" with the name of the app setting that contains your Event Hub connection string.

#You can refer to these resources for more information:
- Azure Functions C# developer reference: https://docs.microsoft.com/en-us/azure/azure-functions/functions-dotnet-class-library
- Send telemetry to Azure Application Insights: https://docs.microsoft.com/en-us/azure/azure-monitor/app/api-custom-events-metrics
- Azure Event Hubs bindings for Azure Functions: https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-hubs-trigger?tabs=csharp