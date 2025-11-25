#### Create PDF from HTML using PuppeteerSharp

To install PuppeteerSharp, use the following .NET CLI command:

- dotnet add package PuppeteerSharp  


```csharp
using System;
using System.IO;
using System.Threading.Tasks;
using PuppeteerSharp;

string sourceDirectory = "/Users/ardeshir/cargill/CDS-FCCustomerServiceHelp/data/Help/";
string destinationDirectory = "/Users/ardeshir/cargill/CDS-FCCustomerServiceHelp/data/PDF/";

// create the destination directory if it doesn't exist  
Directory.CreateDirectory(destinationDirectory);

// get the list of html files  
var htmlFiles = Directory.EnumerateFiles(sourceDirectory, "*.html", SearchOption.AllDirectories);

// Download the Chromium browser if it's not already downloaded  
using var browserFetcher = new BrowserFetcher();
await browserFetcher.DownloadAsync();

foreach (var htmlFile in htmlFiles)
{
    // read the html file content  
    var htmlContent = File.ReadAllText(htmlFile);

    // Initialize a new browser instance  
    using (var browser = await Puppeteer.LaunchAsync(new LaunchOptions { Headless = true }))
    {
        using (var page = await browser.NewPageAsync())
        {
            // Set the page content to the HTML content  
            await page.SetContentAsync(htmlContent);

            // Create a PDF from the page content  
            var pdfBytes = await page.PdfDataAsync(new PdfOptions { Format = PuppeteerSharp.Media.PaperFormat.A4 });

            // Create the pdf file path  
            var pdfFile = Path.Combine(destinationDirectory, Path.GetFileNameWithoutExtension(htmlFile) + ".pdf");

            // Save the PDF  
            await File.WriteAllBytesAsync(pdfFile, pdfBytes);
        }
    }
}

Console.WriteLine("Conversion completed!");  


```
