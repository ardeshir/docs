#### Create a CSharp script that will walk all the files inside a /data directory and replace all blank spaces in filenames with under scores "_" ? 

Here's a C# script that will recursively walk through all files in the "/data" directory and replace any spaces in their filenames with underscores. 

```CSharp
using System;
using System.IO;

class Program
{
    static void Main()
    {
        string dirPath = "/data";

        if(Directory.Exists(dirPath))
        {
            ProcessDirectory(dirPath);
        }
        else
        {
            Console.WriteLine($"Directory '{dirPath}' does not exist.");
        }
    }

    static void ProcessDirectory(string targetDirectory)
    {
        string[] fileEntries = Directory.GetFiles(targetDirectory);
        foreach (string fileName in fileEntries)
            ProcessFile(fileName);

        string[] subdirectoryEntries = Directory.GetDirectories(targetDirectory);
        foreach (string subdirectory in subdirectoryEntries)
            ProcessDirectory(subdirectory);
    }

    static void ProcessFile(string path)
    {
        if (path.Contains(" "))
        {
            string newPath = path.Replace(" ", "_");
            File.Move(path, newPath);
        }
    }
}
```

This script uses `System.IO` namespace to work with files and directories. With the method `Directory.GetFiles(string path)` it retrieves all the file names in the specified path and by `Directory.GetDirectories(string path)` it gets all the subdirectories for a specified directory, it's used to go thru all layers of directories inside the dirPath. 

Before running this script, please make sure that the /data directory exists, and the program has full privilege to read and write files under this directory.

Resource: [File and Stream I/O - Microsoft Docs](https://docs.microsoft.com/en-us/dotnet/standard/io/)
