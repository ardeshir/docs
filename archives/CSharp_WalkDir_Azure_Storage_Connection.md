#### Create a CSharp console program that walks down folders and uploads every HTML file it find in every folder to Azure Cognitive Search's ?

Here is a program to walk down folders and upload HTML files to Azure Blob Storage.

```csharp
using System;
using System.IO;
using System.Threading.Tasks;
using Azure.Storage.Blobs;

public class Program
{
    private const string connectionString = "your connection string";
    private const string containerName = "your container name";
    static async Task Main(string[] args)
    {
        string path = "root directory";
        var blobServiceClient = new BlobServiceClient(connectionString);
        var containerClient = blobServiceClient.GetBlobContainerClient(containerName);
        await WalkDirectoryTree(new DirectoryInfo(path), containerClient);
    }

    static async Task WalkDirectoryTree(DirectoryInfo root, BlobContainerClient containerClient)
    {
        FileInfo[] files = null;
        DirectoryInfo[] subDirs = null;

        try
        {
            files = root.GetFiles("*.html");
        }
        catch (UnauthorizedAccessException e)
        {
            Console.WriteLine(e.Message);
        }
        catch (DirectoryNotFoundException e)
        {
            Console.WriteLine(e.Message);
        }

        if (files != null)
        {
            foreach (FileInfo fi in files)
            {
                await UploadToBlobStorage(fi, containerClient);
            }

            subDirs = root.GetDirectories();

            foreach (DirectoryInfo dirInfo in subDirs)
            {
                await WalkDirectoryTree(dirInfo, containerClient);
            }
        }
    }

    static async Task UploadToBlobStorage(FileInfo file, BlobContainerClient containerClient)
    {
        var blobClient = containerClient.GetBlobClient(file.Name);

        using (var fileStream = File.OpenRead(file.FullName))
        {
            await blobClient.UploadAsync(fileStream, true);
            Console.WriteLine($"Uploaded: {file.Name}");
        }
    }
}

```

Please replace your connection string and your container name with your own Azure Blob Storage connection string and Blob container name. Also, replace root directory with the root directory that you want to start searching for HTML files.

Please refer to the Azure SDK documentation to learn more about uploading blobs: https://docs.microsoft.com/en-us/azure/storage/blobs/storage-quickstart-blobs-dotnet

After you upload the blobs, you can use Azure Cognitive Search to index and search the blobs. Here is the tutorial: https://docs.microsoft.com/en-us/azure/search/search-howto-indexing-azure-blob-storage

