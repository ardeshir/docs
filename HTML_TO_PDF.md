##### Q: How to rewite the entire directly of folders with HTML files, by iterating over them and calling the Convert HTML -> PDFs function with files?

A: In order to open and iterate over directories and folders, you will need to use the System.IO namespace in C#. 
This namespace has classes that allow you to interact with the file system. Here is an example of how you could modify your code:

```csharp
using System.IO;  
using System.Linq;  
  
// Get your directory  
string directoryPath = @"C:\Your\Directory\Path";  
  
// Get all the subdirectories for the specified directory.  
string[] subdirectoryEntries = Directory.GetDirectories(directoryPath);  
  
// Loop through them  
foreach(string subdirectory in subdirectoryEntries)  
{  
    LoadSubDirs(subdirectory);  
}  
  
// Recursive method for loading all subdirectories and their files  
void LoadSubDirs(string dir)  
{  
    Console.WriteLine(dir);  
  
    string[] files = Directory.GetFiles(dir);  
  
    foreach (string file in files)  
    {  
        // Here you can convert each file to a PDF using your converter  
        // Ensure the file is an HTML file before attempting to convert  
        if(Path.GetExtension(file) == ".html")  
        {  
            using (var converter = new Converter())  
            {  
                string pdfPath = Path.ChangeExtension(file, ".pdf");  
                converter.ConvertToPdf(new Uri(file), pdfPath);  
  
                // Show the PDF  
                System.Diagnostics.Process.Start(pdfPath);  
            }  
        }  
    }  
  
    string[] subdirectoryEntries = Directory.GetDirectories(dir);  
  
    foreach(string subdirectory in subdirectoryEntries)  
    {  
        LoadSubDirs(subdirectory);  
    }  
}  
```
# MacOS Path to use 

```csharp
using System;  
using System.IO;  
using System.Linq;  
  
// Get your directory  
string directoryPath = Path.Combine("Users", "ardeshir", "cargill", "CDS-AI-Customer-Service", "data", "Help");  
  
// Get all the subdirectories for the specified directory.  
string[] subdirectoryEntries = Directory.GetDirectories(directoryPath);  
  
// Loop through them  
foreach(string subdirectory in subdirectoryEntries)  
{  
    LoadSubDirs(subdirectory);  
}  
  
// Recursive method for loading all subdirectories and their files  
void LoadSubDirs(string dir)  
{  
    Console.WriteLine(dir);  
  
    string[] files = Directory.GetFiles(dir);  
  
    foreach (string file in files)  
    {  
        // Here you can convert each file to a PDF using your converter  
        // Ensure the file is an HTML file before attempting to convert  
        if(Path.GetExtension(file) == ".html")  
        {  
            using (var converter = new Converter())  
            {  
                string pdfPath = Path.ChangeExtension(file, ".pdf");  
                converter.ConvertToPdf(new Uri(file), pdfPath);  
  
                // Show the PDF  
                System.Diagnostics.Process.Start(pdfPath);  
            }  
        }  
    }  
  
    string[] subdirectoryEntries = Directory.GetDirectories(dir);  
  
    foreach(string subdirectory in subdirectoryEntries)  
    {  
        LoadSubDirs(subdirectory);  
    }  
}  
```

Please note that this code will recursively search through all subdirectories and files within the specified directory. The line if(Path.GetExtension(file) == ".html") ensures that only HTML files are converted to PDFs.

Also, you may need to adjust the converter.ConvertToPdf(new Uri(file), pdfPath); line depending on how your Converter class works. In this example, it's assumed that your Converter can accept a local file path as a Uri. If that's not the case, you will need to adjust this line to fit your needs.

Resources:

Directory.GetDirectories Method
Directory.GetFiles Method
Path.GetExtension Method
Path.ChangeExtension Method
Process.Start Method
