# Queue StateMachine SolverMessage

**Key differences and implications from this `SolverMessage` definition:**

1.  **`RequestBlobName`:** This clearly indicates the incoming message specifies the *request* blob.
2.  **No `ResponseBlobName`:** The worker will need to derive the response blob name (as it was doing in your original code, e.g., by replacing "request-" with "response-").
3.  **`IsSuccessStatusCode`:** This field is interesting. It suggests that the message itself might carry a status from a previous step, or it's intended to be populated *after* this worker processes it if the message is then forwarded. For now, as an input to *this* worker, it might not be used unless this worker is part of a chain where it could receive messages that have already been partially processed. We'll assume it's informational if present on the incoming message but not critical for this worker's primary path.
4.  **Property Casing:** `CorrelationId`, `StorageAccountName`, `ContainerName`, `RequestBlobName`, `IsSuccessStatusCode`. The JSON sent by your load test used lowercase names (e.g., `correlationid`). For `System.Text.Json` to deserialize correctly without explicit `[JsonPropertyName]` attributes, you either need:
    *   The JSON property names to match the C# property names case-sensitively.
    *   Or, set `PropertyNameCaseInsensitive = true` in `JsonSerializerOptions` (which the refactored code already does). So, this should be fine.

Let's update the refactored `QueueStateWorker.cs` based on this `SolverMessage`.

---

**Refactored `QueueStateWorker.cs` (Updated for `SolverMessage`)**

The main changes will be in the `MessageHandler` to use `SolverMessage` and its properties. I will also slightly adjust the `QueueStatePayload` class that is used for sending the *success notification* to the "cloudops-test" topic to better reflect what that topic might expect (which was closer to your original `QueueStatePayload`).

```csharp
// SolverMessage.cs (ensure this class is defined in your project)
// namespace QueueStateMachine; // Or your appropriate namespace
// public class SolverMessage
// {
//     public string? CorrelationId { get; set; }
//     public string? StorageAccountName { get; set; }
//     public string? ContainerName { get; set; }
//     public string? RequestBlobName { get; set; }
//     public bool? IsSuccessStatusCode { get; set; } // Informational for this worker on input

//     public bool IsValidForProcessing()
//     {
//         // StorageAccountName might be optional if worker can get it from global config
//         return !string.IsNullOrEmpty(CorrelationId) &&
//                !string.IsNullOrEmpty(ContainerName) &&
//                !string.IsNullOrEmpty(RequestBlobName);
//     }
// }


// QueueStateWorker.cs (Updated parts marked)
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Azure.Storage.Blobs;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace QueueStateMachine // Ensure this namespace matches your project structure
{
    // Settings classes (JuliaOptimizerSettings, ServiceBusSettings) remain the same as previous response.
    // Add them here or in a separate file.
    public class JuliaOptimizerSettings { /* ... as before ... */ }
    public class ServiceBusSettings { /* ... as before ... */ }


    // Payload for the SUCCESS TOPIC ("cloudops-test")
    // This might be different from the incoming SolverMessage.
    // Based on your original code, it sent StorageAccountName, ContainerName, and the *response* BlobName.
    public class SuccessNotificationPayload
    {
        public string? CorrelationId { get; set; }
        public string? StorageAccountName { get; set; }
        public string? ContainerName { get; set; }
        public string? ResponseBlobName { get; set; } // Specifically the name of the *response* blob
        public bool IsSuccess { get; set; } = true;
    }


    public class QueueStateWorker : BackgroundService
    {
        private readonly ILogger<QueueStateWorker> _logger;
        private readonly IConfiguration _configuration;
        private readonly ServiceBusClient _serviceBusClient;
        private readonly BlobServiceClient _blobServiceClient;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly JuliaOptimizerSettings _juliaSettings;
        private readonly ServiceBusSettings _sbSettings;

        private ServiceBusProcessor? _queueProcessor;
        private ServiceBusSender? _successTopicSender;
        private System.Timers.Timer? _juliaWakeUpTimer;

        // Constructor remains the same as previous response
        public QueueStateWorker(
            ILogger<QueueStateWorker> logger,
            IConfiguration configuration,
            ServiceBusClient serviceBusClient,
            BlobServiceClient blobServiceClient,
            IHttpClientFactory httpClientFactory,
            IOptions<JuliaOptimizerSettings> juliaSettingsOptions,
            IOptions<ServiceBusSettings> sbSettingsOptions)
        {
            _logger = logger;
            _configuration = configuration;
            _serviceBusClient = serviceBusClient;
            _blobServiceClient = blobServiceClient;
            _httpClientFactory = httpClientFactory;
            _juliaSettings = juliaSettingsOptions.Value;
            _sbSettings = sbSettingsOptions.Value;

            if (string.IsNullOrEmpty(_sbSettings.QueueName))
                throw new ArgumentNullException(nameof(_sbSettings.QueueName), "Service Bus QueueName must be configured.");
            if (string.IsNullOrEmpty(_juliaSettings.BaseUrl))
                throw new ArgumentNullException(nameof(_juliaSettings.BaseUrl), "Julia Optimizer BaseUrl must be configured.");
        }


        // ExecuteAsync remains the same as previous response
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("QueueStateWorker starting.");

            var processorOptions = new ServiceBusProcessorOptions
            {
                AutoCompleteMessages = false,
                MaxConcurrentCalls = _sbSettings.MaxConcurrentCalls,
                MaxAutoLockRenewalDuration = TimeSpan.FromMinutes(_sbSettings.MaxAutoLockRenewalMinutes)
            };
            _queueProcessor = _serviceBusClient.CreateProcessor(_sbSettings.QueueName, processorOptions);
            _queueProcessor.ProcessMessageAsync += MessageHandler;
            _queueProcessor.ProcessErrorAsync += ErrorHandler;

            if (!string.IsNullOrEmpty(_sbSettings.SuccessTopicName))
            {
                _successTopicSender = _serviceBusClient.CreateSender(_sbSettings.SuccessTopicName);
            }

            if (!string.IsNullOrEmpty(_juliaSettings.WakeUpPayload))
            {
                _juliaWakeUpTimer = new System.Timers.Timer(TimeSpan.FromMinutes(10).TotalMilliseconds);
                _juliaWakeUpTimer.Elapsed += async (sender, e) => await PerformJuliaWakeUpAsync(stoppingToken);
                _juliaWakeUpTimer.AutoReset = true;
                _juliaWakeUpTimer.Enabled = true;
                _logger.LogInformation("Julia wake-up timer started.");
                await PerformJuliaWakeUpAsync(stoppingToken);
            }

            await _queueProcessor.StartProcessingAsync(stoppingToken);
            _logger.LogInformation("Service Bus processor started for queue: {QueueName}", _sbSettings.QueueName);
            await Task.Delay(Timeout.Infinite, stoppingToken);
            _logger.LogInformation("QueueStateWorker stopping.");
        }

        private async Task MessageHandler(ProcessMessageEventArgs args)
        {
            string body = args.Message.Body.ToString();
            // Use message's CorrelationId if available, otherwise generate one for logging this processing unit
            string logCorrelationId = args.Message.CorrelationId ?? Guid.NewGuid().ToString();

            _logger.LogInformation("[CorrelationId: {LogCorrelationId}] Received message. MessageId: {MessageId}, Body: {Body}",
                logCorrelationId, args.Message.MessageId, body.Substring(0, Math.Min(body.Length, 500))); // Log truncated body

            SolverMessage? solverMessage = null; // *** UPDATED TYPE ***
            try
            {
                // *** USE SolverMessage for deserialization ***
                solverMessage = JsonSerializer.Deserialize<SolverMessage>(body, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                // *** UPDATED VALIDATION based on SolverMessage ***
                if (solverMessage == null ||
                    string.IsNullOrEmpty(solverMessage.CorrelationId) || // Assuming CorrelationId is mandatory from source
                    string.IsNullOrEmpty(solverMessage.ContainerName) ||
                    string.IsNullOrEmpty(solverMessage.RequestBlobName))
                {
                    _logger.LogError("[CorrelationId: {LogCorrelationId}] Invalid or incomplete SolverMessage payload for MessageId: {MessageId}. Payload: {Body}",
                        logCorrelationId, args.Message.MessageId, body);
                    await args.DeadLetterMessageAsync(args.Message, "InvalidPayload", "SolverMessage is null or missing required fields.", args.CancellationToken);
                    return;
                }
                // If message's CorrelationId was null, use the one from the payload now that we have it
                if(string.IsNullOrEmpty(args.Message.CorrelationId) && !string.IsNullOrEmpty(solverMessage.CorrelationId)) {
                    logCorrelationId = solverMessage.CorrelationId;
                }

            }
            catch (JsonException jsonEx)
            {
                _logger.LogError(jsonEx, "[CorrelationId: {LogCorrelationId}] Failed to deserialize SolverMessage for MessageId: {MessageId}. Body: {Body}",
                    logCorrelationId, args.Message.MessageId, body);
                await args.DeadLetterMessageAsync(args.Message, "DeserializationError", jsonEx.Message, args.CancellationToken);
                return;
            }

            // *** USE properties from SolverMessage ***
            var storageAccountName = solverMessage.StorageAccountName ?? _configuration["StorageAccount:Name"]; // Fallback to global config
            var containerName = solverMessage.ContainerName;
            var requestBlobName = solverMessage.RequestBlobName;

            if (string.IsNullOrEmpty(storageAccountName))
            {
                 _logger.LogError("[CorrelationId: {LogCorrelationId}] StorageAccountName missing in SolverMessage and global configuration for MessageId: {MessageId}.",
                    logCorrelationId, args.Message.MessageId);
                 await args.DeadLetterMessageAsync(args.Message, "ConfigurationError", "StorageAccountName missing.", args.CancellationToken);
                 return;
            }

            try
            {
                _logger.LogInformation("[CorrelationId: {LogCorrelationId}] Processing MessageId: {MessageId} for RequestBlob: {StorageAccount}/{Container}/{Blob}",
                    logCorrelationId, args.Message.MessageId, storageAccountName, containerName, requestBlobName);

                string juliaInput = await GetBlobContentAsync(storageAccountName!, containerName!, requestBlobName!, args.CancellationToken);
                _logger.LogDebug("[CorrelationId: {LogCorrelationId}] Julia input for MessageId {MessageId} (first 200 chars): {Input}",
                    logCorrelationId, args.Message.MessageId, juliaInput.Substring(0, Math.Min(juliaInput.Length, 200)));

                string? juliaResponse = await CallJuliaOptimizerAsync(juliaInput, args.CancellationToken);
                if (string.IsNullOrEmpty(juliaResponse))
                {
                    _logger.LogError("[CorrelationId: {LogCorrelationId}] Julia optimizer returned no response or failed for MessageId: {MessageId}.",
                        logCorrelationId, args.Message.MessageId);
                    await args.AbandonMessageAsync(args.Message, cancellationToken: args.CancellationToken);
                    return;
                }
                _logger.LogDebug("[CorrelationId: {LogCorrelationId}] Julia response for MessageId {MessageId} (first 200 chars): {Response}",
                    logCorrelationId, args.Message.MessageId, juliaResponse.Substring(0, Math.Min(juliaResponse.Length, 200)));

                // *** DERIVE response blob name (as SolverMessage doesn't provide it) ***
                string responseBlobName = requestBlobName!.Replace("request-", "response-", StringComparison.OrdinalIgnoreCase);
                // Your original code appended "2" for testing: `blobResponseName = $"{blobResponseName}2";`
                // Consider if a more robust uniqueness mechanism is needed for production if names might collide.
                 responseBlobName = $"{responseBlobName}-{DateTime.UtcNow:yyyyMMddHHmmssfff}"; // Example for uniqueness

                await StoreBlobContentAsync(storageAccountName!, containerName!, responseBlobName, juliaResponse, args.CancellationToken);
                _logger.LogInformation("[CorrelationId: {LogCorrelationId}] Response stored to {StorageAccount}/{Container}/{Blob} for MessageId: {MessageId}",
                    logCorrelationId, storageAccountName, containerName, responseBlobName, args.Message.MessageId);

                if (_successTopicSender != null)
                {
                    // *** USE SuccessNotificationPayload for the outgoing success message ***
                    var successPayload = new SuccessNotificationPayload
                    {
                        CorrelationId = solverMessage.CorrelationId, // Use original correlation ID
                        StorageAccountName = storageAccountName,
                        ContainerName = containerName,
                        ResponseBlobName = responseBlobName, // The name of the blob we just saved
                        IsSuccess = true
                    };
                    var successMessage = new ServiceBusMessage(JsonSerializer.Serialize(successPayload))
                    {
                        ContentType = "application/json",
                        MessageId = Guid.NewGuid().ToString(), // New unique MessageId for this outgoing message
                        CorrelationId = solverMessage.CorrelationId // Preserve original CorrelationId
                    };
                    await _successTopicSender.SendMessageAsync(successMessage, args.CancellationToken);
                    _logger.LogInformation("[CorrelationId: {LogCorrelationId}] Success notification sent to topic {TopicName} for original MessageId: {OriginalMessageId} regarding response blob {ResponseBlob}",
                        logCorrelationId, _sbSettings.SuccessTopicName, args.Message.MessageId, responseBlobName);
                }

                await args.CompleteMessageAsync(args.Message, args.CancellationToken);
                _logger.LogInformation("[CorrelationId: {LogCorrelationId}] MessageId: {MessageId} processed and completed successfully.",
                    logCorrelationId, args.Message.MessageId);
            }
            catch (OperationCanceledException) when (args.CancellationToken.IsCancellationRequested)
            {
                _logger.LogWarning("[CorrelationId: {LogCorrelationId}] Processing canceled for MessageId: {MessageId} due to shutdown request.",
                    logCorrelationId, args.Message.MessageId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[CorrelationId: {LogCorrelationId}] Unhandled error processing MessageId: {MessageId}. Error: {ErrorMessage}",
                    logCorrelationId, args.Message.MessageId, ex.Message);
                await args.DeadLetterMessageAsync(args.Message, "ProcessingFailure", ex.ToStringDemystified(), args.CancellationToken);
            }
        }

        // GetBlobContentAsync, StoreBlobContentAsync, CallJuliaOptimizerAsync, PerformJuliaWakeUpAsync, ErrorHandler, StopAsync
        // remain the same as in the previous response. I'll include them here for completeness if you wish,
        // or you can refer to the previous comprehensive response for those method bodies.
        // For brevity, I'll omit them here, assuming they are unchanged.
        // ... (Paste those methods here from previous response) ...
         private async Task<string> GetBlobContentAsync(string storageAccountName, string containerName, string blobName, CancellationToken cancellationToken)
        {
            _logger.LogDebug("[CorrelationId: {CorrelationId}] Fetching blob: {Account}/{Container}/{Blob}", Thread.CurrentThread.Name, storageAccountName, containerName, blobName);
            var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
            var blobClient = containerClient.GetBlobClient(blobName);

            if (!await blobClient.ExistsAsync(cancellationToken))
            {
                _logger.LogError("[CorrelationId: {CorrelationId}] Blob not found: {Account}/{Container}/{Blob}", Thread.CurrentThread.Name, storageAccountName, containerName, blobName);
                throw new FileNotFoundException($"Blob {blobName} not found in {containerName}.");
            }

            using var stream = await blobClient.OpenReadAsync(new BlobOpenReadOptions(false), cancellationToken);
            using var reader = new StreamReader(stream, Encoding.UTF8);
            return await reader.ReadToEndAsync(cancellationToken);
        }

        private async Task StoreBlobContentAsync(string storageAccountName, string containerName, string blobName, string content, CancellationToken cancellationToken)
        {
            _logger.LogDebug("[CorrelationId: {CorrelationId}] Storing blob: {Account}/{Container}/{Blob}", Thread.CurrentThread.Name, storageAccountName, containerName, blobName);
            var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
            var blobClient = containerClient.GetBlobClient(blobName);

            using var memoryStream = new MemoryStream(Encoding.UTF8.GetBytes(content));
            await blobClient.UploadAsync(memoryStream, overwrite: true, cancellationToken: cancellationToken);
        }


        private async Task<string?> CallJuliaOptimizerAsync(string payload, CancellationToken cancellationToken)
        {
            string? logCorrelationId = null; // Placeholder for correlation if available contextually
            try { logCorrelationId = JsonSerializer.Deserialize<SolverMessage>(payload)?.CorrelationId; } catch {} // Best effort

            _logger.LogDebug("[CorrelationId: {CorrelationId}] Calling Julia optimizer. Payload size: {PayloadSize}", logCorrelationId ?? "N/A", payload.Length);
            var httpClient = _httpClientFactory.CreateClient("JuliaOptimizer");

            try
            {
                var content = new StringContent(payload, Encoding.UTF8, "application/json");
                var response = await httpClient.PostAsync("glopar/v2", content, cancellationToken); // Assuming "glopar/v2" is the correct relative path

                if (response.IsSuccessStatusCode)
                {
                    var responseString = await response.Content.ReadAsStringAsync(cancellationToken);
                    _logger.LogInformation("[CorrelationId: {CorrelationId}] Julia optimizer call successful.", logCorrelationId ?? "N/A");
                    return responseString;
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                    _logger.LogError("[CorrelationId: {CorrelationId}] Julia optimizer call failed. Status: {StatusCode}, Response: {ErrorResponse}", logCorrelationId ?? "N/A", response.StatusCode, errorContent);
                    return null;
                }
            }
            catch (HttpRequestException httpEx)
            {
                _logger.LogError(httpEx, "[CorrelationId: {CorrelationId}] HTTP request to Julia optimizer failed.", logCorrelationId ?? "N/A");
                return null;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                 _logger.LogWarning("[CorrelationId: {CorrelationId}] Julia optimizer call cancelled.", logCorrelationId ?? "N/A");
                 return null;
            }
        }
        private async Task PerformJuliaWakeUpAsync(CancellationToken cancellationToken)
        {
            if (string.IsNullOrEmpty(_juliaSettings.WakeUpPayload)) return;

            _logger.LogInformation("Attempting to wake up Julia optimizer.");
            try
            {
                // The wake-up payload might not have a correlation ID in itself, so context is limited here.
                var response = await CallJuliaOptimizerAsync(_juliaSettings.WakeUpPayload, cancellationToken);
                if (!string.IsNullOrEmpty(response))
                {
                    _logger.LogInformation("Julia optimizer wake-up call successful.");
                }
                else
                {
                    _logger.LogWarning("Julia optimizer wake-up call did not return a successful response or failed.");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during Julia optimizer wake-up call.");
            }
        }

        private Task ErrorHandler(ProcessErrorEventArgs args)
        {
            // Try to get CorrelationId from the failed message if available
            string? correlationId = "N/A";
            if (args.Exception is ServiceBusException sbException && sbException.Message != null)
            {
                try
                {
                    // This is a guess, actual message might not be easily accessible here
                    // For more advanced scenarios, you might need to inspect args.Exception further
                    // or rely on the MessageHandler to have logged the CorrelationId before failure.
                } catch {}
            }

            _logger.LogError(args.Exception, "[CorrelationId: {CorrelationId}] Error in ServiceBusProcessor. EntityPath: {EntityPath}, ErrorSource: {ErrorSource}, FullyQualifiedNamespace: {Namespace}",
                correlationId, args.EntityPath, args.ErrorSource, args.FullyQualifiedNamespace);
            return Task.CompletedTask;
        }

        public override async Task StopAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("QueueStateWorker.StopAsync called.");
            if (_juliaWakeUpTimer != null)
            {
                _juliaWakeUpTimer.Stop();
                _juliaWakeUpTimer.Dispose();
                _logger.LogInformation("Julia wake-up timer stopped and disposed.");
            }
            if (_queueProcessor != null)
            {
                _logger.LogInformation("Stopping ServiceBusProcessor for queue {QueueName}.", _sbSettings.QueueName);
                await _queueProcessor.StopProcessingAsync(CancellationToken.None);
                await _queueProcessor.DisposeAsync();
                _logger.LogInformation("ServiceBusProcessor for queue {QueueName} stopped and disposed.", _sbSettings.QueueName);
            }
            if (_successTopicSender != null)
            {
                 await _successTopicSender.DisposeAsync();
                 _logger.LogInformation("ServiceBusSender for success topic {TopicName} disposed.", _sbSettings.SuccessTopicName);
            }
            await base.StopAsync(stoppingToken);
            _logger.LogInformation("QueueStateWorker stopped completely.");
        }
    }
}
```

**Summary of Changes in `QueueStateWorker.cs` based on `SolverMessage`:**

1.  **Deserialization Target:** Changed from `QueueStatePayload` to `SolverMessage`.
2.  **Payload Validation:** Updated to check required fields from `SolverMessage` (e.g., `CorrelationId`, `ContainerName`, `RequestBlobName`).
3.  **Property Access:** Now uses `solverMessage.CorrelationId`, `solverMessage.StorageAccountName`, `solverMessage.ContainerName`, `solverMessage.RequestBlobName`.
4.  **Response Blob Name Derivation:** Logic to derive `responseBlobName` from `requestBlobName` is retained and made more explicit (e.g., adding a timestamp for uniqueness, which you can customize).
5.  **Success Notification Payload:** A new class `SuccessNotificationPayload` is introduced to represent the message sent to the "cloudops-test" topic. This payload includes the `ResponseBlobName`.
6.  **Correlation ID Logging:** Enhanced logging to use the correlation ID from the `SolverMessage` (or the Service Bus message property) consistently.
7.  **`GetBlobContentAsync`, etc.:** These helper methods are largely the same but I've re-pasted them above for completeness and added some contextual logging for Correlation ID.

**Next Steps:**

1.  **Define `SolverMessage.cs`:** Make sure the `SolverMessage` class definition you provided is in a `.cs` file within your `QueueStateMachine` project (e.g., `SolverMessage.cs`) and in the correct namespace.
2.  **Define `JuliaOptimizerSettings.cs` and `ServiceBusSettings.cs`** (and `StorageAccountSettings.cs` if you use it explicitly in `Program.cs`) for the Options pattern, or include them in `QueueStateWorker.cs`.
3.  **Review `Program.cs` and `appsettings.json`:** The `Program.cs` and `appsettings.json` from my *previous comprehensive response* should still be mostly correct. The main thing to ensure is that `ServiceBus:QueueName` in `appsettings.json` points to the queue where messages in the `SolverMessage` format are sent.
4.  **Test:**
    *   Ensure your `QueueStateMachineLoadTest` program sends messages that correctly serialize to the `SolverMessage` structure (especially considering property casing if `PropertyNameCaseInsensitive` wasn't used by the sender, though the worker now uses it).
    *   Run the `QueueStateMachine` (this refactored worker).
    *   Send messages using your load tester.
    *   Check logs for correct processing, correlation IDs, blob operations, and messages to the "cloudops-test" topic.

This brings the refactored sidecar code much closer to your actual operational logic.
