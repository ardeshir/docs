##### Update Maintenance:

Update this function to make an API call for the following URL, and get a token, to then call the Service below, and use CSharp Date libraries to create UTC maintenanceStartDate and maintenanceEndDate from mm/dd/yyyy hh:mm:ss format. 

        services.AddHttpClient("SquadcastAuth", client =>
        {
            client.DefaultRequestHeaders.Add("X-Refresh-Token", config.GetValue<string>(ConfigKeys.SquadcastApiKey));
            client.BaseAddress = new Uri("https://auth.squadcast.com/oauth/access-token");
        });

``` csharp function to update: 

public static class HttpTriggerCSharp
{
    private static readonly HttpClient client = new HttpClient();
    
    [FunctionName("MaintenanceFunction")]
    public static async Task Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
        ILogger log, ExecutionContext context)
    {
        var serviceID = req.Query["serviceID"];
        var maintenanceStartDate = req.Query["maintenanceStartDate"];
        var maintenanceStartTime = req.Query["maintenanceStartTime"];
        var maintenanceEndDate = req.Query["maintenanceEndDate"];
        var maintenanceEndTime = req.Query["maintenanceEndTime"];
    
        var uri = new Uri($"https://api.squadcast.com/v3/services/{serviceID}/maintenance");
    
        var json = $@"{{
                        ""data"":   
                        {{
                            ""onMaintenance"": true,  
                            ""serviceMaintenance"":   
                            [
                                {{
                                    ""daily"": false,  
                                    ""days"": [],  
                                    ""maintenanceEndDate"": ""{maintenanceEndDate}"",  
                                    ""maintenanceEndTime"": ""{maintenanceEndTime}"",  
                                    ""maintenanceStartDate"": ""{maintenanceStartDate}"",  
                                    ""maintenanceStartTime"": ""{maintenanceStartTime}"",  
                                    ""monthly"": false,  
                                    ""repeatTill"": ""{maintenanceEndDate}"",  
                                    ""repetition"": false,  
                                    ""status"": ""New Maintenance Schedule"",  
                                    ""weekly"": false  
                                }}
                            ]  
                        }}  
                    }}";
    
        var content = new StringContent(json, Encoding.UTF8, "application/json");
    
        //var azureServiceTokenProvider = new AzureServiceTokenProvider();
        //var kvClient = new KeyVaultClient(new KeyVaultClient.AuthenticationCallback(azureServiceTokenProvider.KeyVaultTokenCallback));
        //var secret = await kvClient.GetSecretAsync(Environment.GetEnvironmentVariable("SquadcastSecretUri"));
                    /* new keyvault grab */
            string secretName = "SquadcastSecretUri";
            var vaultUri = new Uri("https://kv-fsdi-shrdsvc-techops.vault.azure.net/");
           
            // var secretClient = new SecretClient(vaultUri, HelperMethods.GetDefaultAzureCredential());
            var credential = new ManagedIdentityCredential();
            var secretClient = new SecretClient(vaultUri, credential);
            log.LogInformation($"Pulling {secretName} secret");
            var secretResponse = await secretClient.GetSecretAsync(secretName);
            var secret = secretResponse.Value;
            /* end of keyvault grab */
        
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", secret.Value);

        var response = await client.PostAsync(uri, content);
    
        response.EnsureSuccessStatusCode();
    
        string responseBody = await response.Content.ReadAsStringAsync();
    
        log.LogInformation(responseBody);
    }
}

```

The service should work by using curl example data json POST body forthis URL : 
https://ca-cds-zyjkdnmamcrxa.graycliff-d72883b5.eastus.azurecontainerapps.io/
That also contains 'serviceID'  as well as the following body 
'{
    "data": {
        "onMaintenance": true,
        "serviceMaintenance": [
            {
                "daily": false,
                "days": [],
                "maintenanceEndDate": "2022-03-01T11:00:00.000Z",
                "maintenanceEndTime": "16:30",
                "maintenanceStartDate": "2022-03-01T09:30:00.000Z",
                "maintenanceStartTime": "15:00",
                "monthly": false,
                "repeatTill": "2022-03-01T11:00:00.000Z",
                "repetition": false,
                "status": "New Maintenance Schedule",
                "weekly": false
            }
        ]
    }
}'

To test this main CSharp Task Main() function call: 
```csharp 
static async Task Main()
    {
        var uri = new Uri("https://api.squadcast.com/v3/services/:serviceID/maintenance");

        var json = @"{
                        ""data"": 
                        {
                            ""onMaintenance"": true,
                            ""serviceMaintenance"": 
                            [
                                {
                                    ""daily"": false,
                                    ""days"": [],
                                    ""maintenanceEndDate"": ""2022-03-01T11:00:00.000Z"",
                                    ""maintenanceEndTime"": ""16:30"",
                                    ""maintenanceStartDate"": ""2022-03-01T09:30:00.000Z"",
                                    ""maintenanceStartTime"": ""15:00"",
                                    ""monthly"": false,
                                    ""repeatTill"": ""2022-03-01T11:00:00.000Z"",
                                    ""repetition"": false,
                                    ""status"": ""New Maintenance Schedule"",
                                    ""weekly"": false
                                }
                            ]
                        }
                    }";

        var content = new StringContent(json, Encoding.UTF8, "application/json");

        var response = await client.PostAsync(uri, content);

        response.EnsureSuccessStatusCode();

        string responseBody = await response.Content.ReadAsStringAsync();

        Console.WriteLine(responseBody);
    }
}
```


### A: 
To make an authenticated API call to Squadcast, you first need to obtain a token from the authentication URL. 

Here, the given HttpRequest already has many query parameters which likely include the input dates. So you need to convert these date strings to the UTC format using DateTimeOffset struct. Then, get the token and use it in the header for the subsequent API calls.

Let's add these features to your C# function:

```csharp
public static class HttpTriggerCSharp
{
    private static readonly HttpClient client = new HttpClient();
    
    [FunctionName("MaintenanceFunction")]
    public static async Task Run(
        [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,
        ILogger log, ExecutionContext context)
    {
        var serviceID = req.Query["serviceID"];
        
        var maintenanceStartDateString = req.Query["maintenanceStartDate"];
        var maintenanceStartTimeString = req.Query["maintenanceStartTime"];
        var maintenanceEndDateString = req.Query["maintenanceEndDate"];
        var maintenanceEndTimeString = req.Query["maintenanceEndTime"];

        // Convert input date-time string to DateTimeOffset UTC format
        var maintenanceStartDateTimeOffset = DateTimeOffset.ParseExact(maintenanceStartDateString + " " + maintenanceStartTimeString, "MM/dd/yyyy HH:mm:ss", null).ToUniversalTime();
        var maintenanceEndDateTimeOffset = DateTimeOffset.ParseExact(maintenanceEndDateString + " " + maintenanceEndTimeString, "MM/dd/yyyy HH:mm:ss", null).ToUniversalTime();

        var maintenanceStartDate = maintenanceStartDateTimeOffset.ToString("yyyy-MM-ddTHH\\:mm\\:ss.fffffffZ");
        var maintenanceEndDate = maintenanceEndDateTimeOffset.ToString("yyyy-MM-ddTHH\\:mm\\:ss.fffffffZ");

        var uri = new Uri($"https://api.squadcast.com/v3/services/{serviceID}/maintenance");
        
        var json = $@"{{
                    ""data"":   
                    {{
                        ""onMaintenance"": true,  
                        ""serviceMaintenance"":   
                        [
                            {{
                                ""daily"": false,  
                                ""days"": [],  
                                ""maintenanceEndDate"": ""{maintenanceEndDate}"",  
                                ""maintenanceEndTime"": ""{maintenanceEndTimeString}"",  
                                ""maintenanceStartDate"": ""{maintenanceStartDate}"",  
                                ""maintenanceStartTime"": ""{maintenanceStartTimeString}"",  
                                ""monthly"": false,  
                                ""repeatTill"": ""{maintenanceEndDate}"",  
                                ""repetition"": false,  
                                ""status"": ""New Maintenance Schedule"",  
                                ""weekly"": false  
                            }}
                        ]  
                    }}  
                }}";

        var content = new StringContent(json, Encoding.UTF8, "application/json");

        // Request for token from the Auth Server
        var authTokenResponse = await client.PostAsync("https://auth.squadcast.com/oauth/access-token", new StringContent(config.GetValue<string>(ConfigKeys.SquadcastApiKey), Encoding.UTF8, "application/json"));

        if (authTokenResponse.IsSuccessStatusCode)
        {
            dynamic responseJson = JsonConvert.DeserializeObject(await authTokenResponse.Content.ReadAsStringAsync());
            string authToken = responseJson.access_token;
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", authToken);
        }

        var response = await client.PostAsync(uri, content);
    
        response.EnsureSuccessStatusCode();
    
        string responseBody = await response.Content.ReadAsStringAsync();
    
        log.LogInformation(responseBody);
    }
}
```

In the above code:

1. Convert the date from the format "MM/dd/yyyy HH:mm:ss" to DateTimeOffset.
2. Convert DateTimeOffset to the format "yyyy-MM-ddTHH\\:mm\\:ss.fffffffZ" needed by the Squadcast API.
3. Then get the Auth token from the auth server using HttpClient PostAsync method and set the token to the request header.

For the testing of the Main method, you'd have to replicate similar changes. Please adjust your service/function according to your requirements.

Note: Make sure to include necessary namespaces like System, System.Net, System.Net.Http, System.Net.Http.Headers and Azure.Identity.

