#### Create an index.html file with a list of Links with PDF file names


```csharp 
using System;
using System.IO;
using System.Text;

class Program
{
    static void Main()
    {
        const string dirPath = "./data";
        const string outputPath = "./index.html";

        // Check if the directory exists
        if (!Directory.Exists(dirPath))
        {
            Console.WriteLine($"Directory '{dirPath}' does not exist.");
            return;
        }

        // Get pdf files
        var pdfFiles = Directory.GetFiles(dirPath, "*.pdf");

        // Sort the file names in alphabetical order
        Array.Sort(pdfFiles, StringComparer.InvariantCulture);

        var sb = new StringBuilder();

        sb.AppendLine("<html><title> PDF files</title>");
        sb.AppendLine("<body>");
        sb.AppendLine("<h1>List of ebooks</h1>");
        sb.AppendLine("<ul>");

        // Create a list item for each pdf file
        foreach (var pdfFile in pdfFiles)
        {
            var fileName = Path.GetFileName(pdfFile);
            var linkText = Path.GetFileNameWithoutExtension(fileName).Replace("_", " "); // Replace underscores with spaces
            sb.AppendLine($"<li><a href=\"{fileName}\">{linkText}</a></li>");
        }

        sb.AppendLine("</ul>");
        sb.AppendLine("</body>");
        sb.AppendLine("</html>");

        // Write to output file
        File.WriteAllText(outputPath, sb.ToString());

        Console.WriteLine("Index.html has been created.");
    }
}
```
