####  Azure DevOps REST API to get work items and the Azure SDK for .NET to upload them into Azure Storage.

First, you need to generate a Personal Access Token (PAT) from Azure DevOps. You can follow this guide on how to do that: https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page

```csharp
using System;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Azure.Storage.Blobs;

public class Program
{
    private const string azureDevOpsUrl = "https://dev.azure.com/fsdi/Unity/_apis/wit/wiql?api-version=6.0";
    private const string personalAccessToken = "your personal access token";
    private const string storageAccountConnectionString = "your storage account connection string";
    private const string containerName = "content";

    public static async Task Main(string[] args)
    {
        var httpClient = new HttpClient();
        var byteArray = Encoding.ASCII.GetBytes($":{personalAccessToken}");
        httpClient.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Basic", Convert.ToBase64String(byteArray));

        var workItems = await httpClient.GetStringAsync(azureDevOpsUrl);

        var blobServiceClient = new BlobServiceClient(storageAccountConnectionString);
        var containerClient = blobServiceClient.GetBlobContainerClient(containerName);

        var blobClient = containerClient.GetBlobClient("WorkItems.txt");

        using (var ms = new MemoryStream())
        {
            LoadStreamWithJson(ms, workItems);
            ms.Position = 0;
            await blobClient.UploadAsync(ms, true);
        }

        Console.WriteLine("Uploaded work items.");
    }

    private static void LoadStreamWithJson(Stream ms, string json)
    {
        StreamWriter writer = new StreamWriter(ms);
        writer.Write(json);
        writer.Flush();
        ms.Position = 0;
    }
}

```

This example uses a WIQL (Work Item Query Language) request to get all work items. You may want to change this to only get certain work items or to add additional fields.

Please replace your personal access token and your storage account connection string with your own personal access token and storage account connection string.

The work items from Azure DevOps will be saved in a blob named "WorkItems.txt" in the specified container in the Azure Storage account.

You can find more information on how to use the Azure DevOps REST API here: https://docs.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-6.0

To create this program from scratch using .NET CLI, you need to perform the following steps:
First, make sure you have the .NET 8 SDK installed on your machine. You can download it from here. After installing, you can verify your installation by running the following command in your terminal:
- dotnet --version  
 
2. Create a new console project by running:
- dotnet new console -n YourProjectName  
 
This will create a new folder named YourProjectName with a new console project inside it.

3. Navigate into your new project folder:
- cd YourProjectName  
 
4. Add the necessary packages. For this program, you need Azure.Storage.Blobs for Azure Blob Storage and System.Net.Http for making HTTP requests:
- dotnet add package Azure.Storage.Blobs  
- dotnet add package System.Net.Http  
 
5. Now, open the Program.cs file in your preferred text editor and replace the existing code with the code provided in the previous response.

6. Finally, you can run the program by executing the following command in your terminal:

`dotnet run`  
 
Remember to replace "YourProjectName" with your desired project name. Also note that as of writing, .NET 8 is not yet released. The latest stable version is .NET 5.0 and the upcoming version is .NET 6.0.


