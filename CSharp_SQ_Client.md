##### CSharp SQ cli call to make maintenance window

C# program using dotnet version 6, which calls the mentioned API. As a library, you can use `HttpClient` from `System.Net.Http`, which is included with dotnet and does not require installation. 

```csharp
using System;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

class MainClass
{
    private static readonly HttpClient client = new HttpClient();
    
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

Note: 

1. You may have to update the `serviceID` in the URL(`https://api.squadcast.com/v3/services/:serviceID/maintenance`) with appropriate value.
   
2. You need to handle Errors & Exception appropriately depending on your program need.

To develop in dotnet version 6, installation is required.

Dotnet version 6 can be installed from [here](https://dotnet.microsoft.com/download/dotnet/6.0) and then selecting your OS and download SDK. Once downloaded, execute the .exe file and follow the instructions to complete the installation. After the installation is completed, you will be able to access dotnet CLI.

To verify the installation, open command prompt and execute the command `dotnet --version`. It should return `6.x.x` where `x` is a digit representing the minor version.

