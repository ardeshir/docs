##### Create a dotnet csharp program HTML -> PDFs

1- walks down a directory  "./data/help/"  of folders, and when it finds an *.html files, it  converts them to PDF Files saves them in ./data/PDF/ folder 

- Open your terminal.
- Navigate to the directory where you want to create the project.

Create a new console application project. You can do this by running the following command:
- dotnet new console -o HtmlToPdfConverter  
 
This command creates a new console application in a folder named HtmlToPdfConverter.

4. Navigate to the project directory:
- cd HtmlToPdfConverter  
 
5. Add the SelectPdf package to your project. Unfortunately, SelectPdf is not available in .NET Core yet, but you can use a similar package called DinkToPdf. You can add it by running:
- dotnet add package DinkToPdf  
 
6. Create a new file in the project directory named "Program.cs" and open it in a text editor.

7. Replace the existing code in "Program.cs" with the following:


```csharp 

using System;  
using System.IO;  
using DinkToPdf;  
using DinkToPdf.Contracts;  
  
namespace HtmlToPdfConverter  
{  
    class Program  
    {  
        static void Main(string[] args)  
        {  
            string sourceDirectory = "./data/help/";  
            string destinationDirectory = "./data/PDF/";  
  
            // create the destination directory if it doesn't exist  
            Directory.CreateDirectory(destinationDirectory);  
  
            // get the list of html files  
            var htmlFiles = Directory.EnumerateFiles(sourceDirectory, "*.html", SearchOption.AllDirectories);  
  
            //Initialize the converter  
            var converter = new SynchronizedConverter(new PdfTools());  
  
            foreach (var htmlFile in htmlFiles)  
            {  
                // read the html file content  
                var htmlContent = File.ReadAllText(htmlFile);  
  
                var doc = new HtmlToPdfDocument()  
                {  
                    GlobalSettings = {  
                        ColorMode = ColorMode.Color,  
                        Orientation = Orientation.Portrait,  
                        PaperSize = PaperKind.A4,  
                    },  
                    Objects = {  
                        new ObjectSettings() {  
                            PagesCount = true,  
                            HtmlContent = htmlContent,  
                            WebSettings = { DefaultEncoding = "utf-8" },  
                        }  
                    }  
                };  
  
                // create the pdf file path  
                var pdfFile = Path.Combine(destinationDirectory, Path.GetFileNameWithoutExtension(htmlFile) + ".pdf");  
  
                // convert html content to pdf document  
                byte[] pdf = converter.Convert(doc);  
  
                // save pdf document  
                File.WriteAllBytes(pdfFile, pdf);  
            }  
  
            Console.WriteLine("Conversion completed!");  
        }  
    }  
}```  
 
8. Save and close the file.

9. Run the program with the command:
dotnet run  
 
This program will convert all the HTML files present in the sourceDirectory and its subdirectories to PDF files and save them in the destinationDirectory. Please ensure that the source directory path and destination directory path are correctly set.

Please note that DinkToPdf is a wrapper around wkhtmltopdf utility. It requires libwkhtmltox library to be installed on the system. You can find more details about it on the DinkToPdf GitHub page.


