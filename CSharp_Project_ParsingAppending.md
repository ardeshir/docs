# CSharp Project:  .NET 9 / C# 12 CLI Tools

**Project Goals:**

1.  Read a `data.json` file.
2.  Parse its content.
3.  Convert the parsed JSON to a Markdown string.
4.  Find a target Markdown file in a specified directory using a regex pattern.
5.  Archive the *original* target Markdown file (if found) by renaming it with a timestamp.
6.  Append the generated Markdown to the (new or existing) target Markdown file (using its original name).
7.  Archive the *original* `data.json` file by renaming it with a timestamp.
8.  Use `System.CommandLine` for a good CLI experience.
9.  Structure the code into logical classes/modules for future extensibility.

---

**Step 1: Create the .NET CLI Project**

1.  Open your terminal or command prompt.
2.  Create a new console application:
    ```bash
    dotnet new console -n JsonToMarkdownAppender -f net9.0
    cd JsonToMarkdownAppender
    ```
3.  (Optional but recommended for .NET 9 preview features if any are used explicitly, though not strictly necessary for this example): Create or edit `Directory.Build.props` in the project root:
    ```xml
    <Project>
      <PropertyGroup>
        <LangVersion>12.0</LangVersion>
        <EnablePreviewFeatures>True</EnablePreviewFeatures> <!-- If using preview APIs -->
      </PropertyGroup>
    </Project>
    ```
    *Note: For C# 12 features, `LangVersion` 12.0 is usually sufficient. `EnablePreviewFeatures` is more for SDK/runtime previews.*

---

**Step 2: Add Necessary NuGet Packages**

We'll use `System.Text.Json` for JSON processing and `System.CommandLine` for robust CLI argument parsing.

```bash
dotnet add package System.Text.Json
dotnet add package System.CommandLine
```

---

**Step 3: Define Core Interfaces (for Modularity)**

Let's define interfaces for the key operations. This will allow us to swap out implementations later.

Create a new folder `Core` and add these files:

**`Core/IJsonProcessor.cs`**:
```csharp
// Core/IJsonProcessor.cs
namespace JsonToMarkdownAppender.Core;

/// <summary>
/// Defines a contract for processing JSON content into a structured object.
/// </summary>
/// <typeparam name="T">The type of the structured object to parse into.</typeparam>
public interface IJsonProcessor<T>
{
    Task<T?> ProcessAsync(string filePath);
}
```

**`Core/IMarkdownConverter.cs`**:
```csharp
// Core/IMarkdownConverter.cs
namespace JsonToMarkdownAppender.Core;

/// <summary>
/// Defines a contract for converting a structured object to a Markdown string.
/// </summary>
/// <typeparam name="T">The type of the structured object to convert from.</typeparam>
public interface IMarkdownConverter<T>
{
    string Convert(T data);
}
```

**`Core/IFileFinder.cs`**:
```csharp
// Core/IFileFinder.cs
namespace JsonToMarkdownAppender.Core;

/// <summary>
/// Defines a contract for finding a file based on a pattern.
/// </summary>
public interface IFileFinder
{
    string? FindFile(string directoryPath, string pattern);
}
```

**`Core/IFileArchiver.cs`**:
```csharp
// Core/IFileArchiver.cs
namespace JsonToMarkdownAppender.Core;

/// <summary>
/// Defines a contract for archiving a file.
/// </summary>
public interface IFileArchiver
{
    Task<string?> ArchiveAsync(string filePath, string? archiveSubdirectory = null);
}
```

**`Core/IFileWriter.cs`**:
```csharp
// Core/IFileWriter.cs
namespace JsonToMarkdownAppender.Core;

/// <summary>
/// Defines a contract for writing content to a file.
/// </summary>
public interface IFileWriter
{
    Task AppendAsync(string filePath, string content);
}
```

---

**Step 4: Implement Concrete Services**

Create a new folder `Services` and add implementations for the interfaces.

**Define a simple data model for our `data.json`:**
Let's assume `data.json` looks like this:
```json
{
  "title": "My New Section",
  "author": "AI Assistant",
  "paragraphs": [
    "This is the first paragraph from the JSON data.",
    "Another interesting point to make."
  ],
  "tags": ["update", "csharp", "dotnet"]
}
```

Create `Models/JsonContent.cs`:
```csharp
// Models/JsonContent.cs
using System.Collections.Generic;
using System.Text.Json.Serialization;

namespace JsonToMarkdownAppender.Models;

public class JsonContent
{
    [JsonPropertyName("title")]
    public string? Title { get; set; }

    [JsonPropertyName("author")]
    public string? Author { get; set; }

    [JsonPropertyName("paragraphs")]
    public List<string>? Paragraphs { get; set; }

    [JsonPropertyName("tags")]
    public List<string>? Tags { get; set; }
}
```

**`Services/DefaultJsonProcessor.cs`**:
```csharp
// Services/DefaultJsonProcessor.cs
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using JsonToMarkdownAppender.Core;
using JsonToMarkdownAppender.Models; // Assuming your JsonContent model is here

namespace JsonToMarkdownAppender.Services;

public class DefaultJsonProcessor : IJsonProcessor<JsonContent>
{
    public async Task<JsonContent?> ProcessAsync(string filePath)
    {
        if (!File.Exists(filePath))
        {
            Console.Error.WriteLine($"Error: JSON file not found at '{filePath}'.");
            return null;
        }

        try
        {
            var jsonString = await File.ReadAllTextAsync(filePath);
            return JsonSerializer.Deserialize<JsonContent>(jsonString, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true // Good practice
            });
        }
        catch (JsonException ex)
        {
            Console.Error.WriteLine($"Error parsing JSON file '{filePath}': {ex.Message}");
            return null;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"An unexpected error occurred while reading JSON file '{filePath}': {ex.Message}");
            return null;
        }
    }
}
```

**`Services/SimpleMarkdownConverter.cs`**:
```csharp
// Services/SimpleMarkdownConverter.cs
using System.Linq;
using System.Text;
using JsonToMarkdownAppender.Core;
using JsonToMarkdownAppender.Models;

namespace JsonToMarkdownAppender.Services;

public class SimpleMarkdownConverter : IMarkdownConverter<JsonContent>
{
    public string Convert(JsonContent data)
    {
        var sb = new StringBuilder();
        sb.AppendLine($"## {data.Title ?? "Untitled Section"}"); // Use H2 for appended sections

        if (!string.IsNullOrWhiteSpace(data.Author))
        {
            sb.AppendLine($"_By: {data.Author}_");
            sb.AppendLine();
        }

        if (data.Paragraphs != null && data.Paragraphs.Any())
        {
            foreach (var p in data.Paragraphs)
            {
                sb.AppendLine(p);
                sb.AppendLine(); // Add an empty line for paragraph spacing in Markdown
            }
        }

        if (data.Tags != null && data.Tags.Any())
        {
            sb.AppendLine($"Tags: {string.Join(", ", data.Tags.Select(t => $"`{t}`"))}");
            sb.AppendLine();
        }
        sb.AppendLine("---"); // Add a horizontal rule for separation
        sb.AppendLine();

        return sb.ToString();
    }
}
```

**`Services/RegexFileFinder.cs`**:
```csharp
// Services/RegexFileFinder.cs
using System;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using JsonToMarkdownAppender.Core;

namespace JsonToMarkdownAppender.Services;

public class RegexFileFinder : IFileFinder
{
    public string? FindFile(string directoryPath, string pattern)
    {
        if (!Directory.Exists(directoryPath))
        {
            Console.Error.WriteLine($"Error: Target directory not found at '{directoryPath}'.");
            return null;
        }

        try
        {
            var regex = new Regex(pattern, RegexOptions.IgnoreCase); // Regex is case-insensitive by default here
            
            // We'll only search the top directory for simplicity, but you could change SearchOption.
            var files = Directory.EnumerateFiles(directoryPath, "*.*", SearchOption.TopDirectoryOnly)
                                 .Where(file => regex.IsMatch(Path.GetFileName(file)));
            
            // Return the first match. You might want different logic for multiple matches.
            return files.FirstOrDefault();
        }
        catch (ArgumentException ex)
        {
            Console.Error.WriteLine($"Error: Invalid regex pattern '{pattern}': {ex.Message}");
            return null;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error searching for files in '{directoryPath}': {ex.Message}");
            return null;
        }
    }
}
```

**`Services/TimestampFileArchiver.cs`**:
```csharp
// Services/TimestampFileArchiver.cs
using System;
using System.IO;
using System.Threading.Tasks;
using JsonToMarkdownAppender.Core;

namespace JsonToMarkdownAppender.Services;

public class TimestampFileArchiver : IFileArchiver
{
    public Task<string?> ArchiveAsync(string filePath, string? archiveSubdirectory = null)
    {
        if (!File.Exists(filePath))
        {
            // It's not an error if the file to archive doesn't exist (e.g., first run for target MD)
            // Console.WriteLine($"Info: File '{filePath}' not found for archiving, skipping.");
            return Task.FromResult<string?>(null);
        }

        try
        {
            string directory = Path.GetDirectoryName(filePath) ?? ".";
            string fileName = Path.GetFileNameWithoutExtension(filePath);
            string extension = Path.GetExtension(filePath);
            string timestamp = DateTime.UtcNow.ToString("yyyyMMddHHmmssfff");

            string archiveFileName = $"{fileName}_{timestamp}{extension}";
            string archivePath;

            if (!string.IsNullOrEmpty(archiveSubdirectory))
            {
                string fullArchiveSubDir = Path.Combine(directory, archiveSubdirectory);
                Directory.CreateDirectory(fullArchiveSubDir); // Ensure archive subdir exists
                archivePath = Path.Combine(fullArchiveSubDir, archiveFileName);
            }
            else
            {
                archivePath = Path.Combine(directory, archiveFileName);
            }
            
            File.Move(filePath, archivePath);
            Console.WriteLine($"Archived '{filePath}' to '{archivePath}'.");
            return Task.FromResult<string?>(archivePath);
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error archiving file '{filePath}': {ex.Message}");
            return Task.FromResult<string?>(null);
        }
    }
}
```

**`Services/DefaultFileWriter.cs`**:
```csharp
// Services/DefaultFileWriter.cs
using System.IO;
using System.Threading.Tasks;
using JsonToMarkdownAppender.Core;

namespace JsonToMarkdownAppender.Services;

public class DefaultFileWriter : IFileWriter
{
    public async Task AppendAsync(string filePath, string content)
    {
        try
        {
            // Ensure directory exists
            string? directory = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }
            await File.AppendAllTextAsync(filePath, content);
            Console.WriteLine($"Appended content to '{filePath}'.");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error appending to file '{filePath}': {ex.Message}");
        }
    }
}
```

---

**Step 5: Create the Main Application Logic Class**

This class will orchestrate the operations using the services.

Create `AppLogic.cs`:
```csharp
// AppLogic.cs
using System;
using System.IO;
using System.Threading.Tasks;
using JsonToMarkdownAppender.Core;
using JsonToMarkdownAppender.Models;

namespace JsonToMarkdownAppender;

public class AppLogic(
    IJsonProcessor<JsonContent> jsonProcessor,
    IMarkdownConverter<JsonContent> markdownConverter,
    IFileFinder fileFinder,
    IFileArchiver fileArchiver,
    IFileWriter fileWriter) // Using primary constructor (C# 12)
{
    public async Task<int> RunAsync(string jsonFilePath, string targetDirectory, string targetFilePattern, string? archiveSubDir)
    {
        Console.WriteLine($"Processing JSON file: {jsonFilePath}");
        Console.WriteLine($"Target directory: {targetDirectory}");
        Console.WriteLine($"Target file pattern: {targetFilePattern}");
        if (!string.IsNullOrEmpty(archiveSubDir))
        {
            Console.WriteLine($"Archive subdirectory: {archiveSubDir}");
        }
        Console.WriteLine("---");

        // 1. Process JSON
        var jsonData = await jsonProcessor.ProcessAsync(jsonFilePath);
        if (jsonData == null)
        {
            Console.Error.WriteLine("Failed to process JSON data. Aborting.");
            return 1; // Error code
        }

        // 2. Convert to Markdown
        string markdownContent = markdownConverter.Convert(jsonData);
        if (string.IsNullOrEmpty(markdownContent))
        {
            Console.Error.WriteLine("Generated Markdown content is empty. Aborting.");
            return 1;
        }
        // Console.WriteLine("Generated Markdown:\n" + markdownContent); // For debugging

        // 3. Find target Markdown file
        string? targetFilePath = fileFinder.FindFile(targetDirectory, targetFilePattern);

        if (targetFilePath != null)
        {
            Console.WriteLine($"Found target file: {targetFilePath}");
            // 4. Archive existing target Markdown file
            await fileArchiver.ArchiveAsync(targetFilePath, archiveSubDir);
        }
        else
        {
            // If no file is found, we'll create one with a name based on the pattern.
            // This is a simple approach; a more robust one might require a specific output filename argument.
            // For now, let's construct a name. E.g. if pattern is "^README.*\.md$", use "README.md".
            // This is a simplification. A more robust approach might be to error out or require an explicit output filename.
            string baseName = targetFilePattern.TrimStart('^').Split(new[] { ".*", ".md" }, StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? "output";
            targetFilePath = Path.Combine(targetDirectory, $"{baseName}.md");
            Console.WriteLine($"No target file found matching pattern. Will create/append to: {targetFilePath}");
        }

        // 5. Append to (new or existing) target file (using original name)
        await fileWriter.AppendAsync(targetFilePath, markdownContent);

        // 6. Archive source JSON file
        await fileArchiver.ArchiveAsync(jsonFilePath, archiveSubDir);
        
        Console.WriteLine("---");
        Console.WriteLine("Operation completed successfully.");
        return 0; // Success
    }
}
```

---

**Step 6: Setup `System.CommandLine` in `Program.cs`**

Modify `Program.cs` to handle command-line arguments.

```csharp
// Program.cs
using System;
using System.CommandLine;
using System.IO;
using System.Threading.Tasks;
using JsonToMarkdownAppender;
using JsonToMarkdownAppender.Core;
using JsonToMarkdownAppender.Models;
using JsonToMarkdownAppender.Services;

class Program
{
    static async Task<int> Main(string[] args)
    {
        var jsonFileOption = new Option<FileInfo>(
            name: "--json-file",
            description: "The input JSON file path.",
            getDefaultValue: () => new FileInfo("data.json")); // Default value

        var targetDirOption = new Option<DirectoryInfo>(
            name: "--target-directory",
            description: "The directory to search for the target Markdown file.",
            getDefaultValue: () => new DirectoryInfo(".")); // Default to current directory

        var targetPatternOption = new Option<string>(
            name: "--target-pattern",
            description: "Regex pattern to find the target Markdown file (e.g., \"^README.*\\.md$\").",
            getDefaultValue: () => "^NOTES.*\\.md$"); // Default pattern

        var archiveSubDirOption = new Option<string?>( // Nullable string for optional argument
            name: "--archive-subdir",
            description: "Optional subdirectory within the source/target file's directory to move archived files to.");

        var rootCommand = new RootCommand("CLI tool to parse JSON, convert to Markdown, and append to a file.");
        rootCommand.AddOption(jsonFileOption);
        rootCommand.AddOption(targetDirOption);
        rootCommand.AddOption(targetPatternOption);
        rootCommand.AddOption(archiveSubDirOption);

        rootCommand.SetHandler(async (jsonFile, targetDir, targetPattern, archiveSubDir) =>
        {
            // Simple Dependency Injection setup (manual for now)
            IJsonProcessor<JsonContent> jsonProcessor = new DefaultJsonProcessor();
            IMarkdownConverter<JsonContent> markdownConverter = new SimpleMarkdownConverter();
            IFileFinder fileFinder = new RegexFileFinder();
            IFileArchiver fileArchiver = new TimestampFileArchiver();
            IFileWriter fileWriter = new DefaultFileWriter();

            var appLogic = new AppLogic(
                jsonProcessor,
                markdownConverter,
                fileFinder,
                fileArchiver,
                fileWriter);

            await appLogic.RunAsync(jsonFile.FullName, targetDir.FullName, targetPattern, archiveSubDir);

        }, jsonFileOption, targetDirOption, targetPatternOption, archiveSubDirOption);

        return await rootCommand.InvokeAsync(args);
    }
}
```

---

**Step 7: Prepare Sample Files and Test**

1.  **Create `data.json` in your project root:**
    ```json
    {
      "title": "My CLI Tool Update",
      "author": "Dev Assistant",
      "paragraphs": [
        "Successfully implemented the CLI tool.",
        "It can parse JSON, convert to Markdown, and append.",
        "Archiving of source and target files is also working."
      ],
      "tags": ["cli", "dotnet9", "csharp12", "automation"]
    }
    ```

2.  **Create a sample target Markdown file, e.g., `NOTES.md` in your project root:**
    ```markdown
    # Project Notes

    This file contains various notes about the project.

    ## Old Section
    Some old content here.

    ---
    ```

3.  **Build the project:**
    ```bash
    dotnet build
    ```

4.  **Run the tool:**

    *   **Using defaults:** (Assumes `data.json` and `NOTES.md` are in the current directory)
        ```bash
        dotnet run
        ```
        This will use `data.json`, look for `^NOTES.*\.md$` in the current directory.

    *   **Specifying options:**
        ```bash
        dotnet run --json-file mydata.json --target-directory ./docs --target-pattern "^CHAPTER.*\\.md$" --archive-subdir "_archive"
        ```
        (You'd need to create `mydata.json` and a `docs` directory with a matching file for this example).

**Expected Outcome (after running with defaults):**

*   A `data_YYYYMMDDHHMMSSFFF.json` file will be created (archive of `data.json`).
*   A `NOTES_YYYYMMDDHHMMSSFFF.md` file will be created (archive of original `NOTES.md`).
*   The `NOTES.md` file will now contain:
    ```markdown
    # Project Notes

    This file contains various notes about the project.

    ## Old Section
    Some old content here.

    ---
    ## My CLI Tool Update
    _By: Dev Assistant_

    Successfully implemented the CLI tool.

    It can parse JSON, convert to Markdown, and append.

    Archiving of source and target files is also working.

    Tags: `cli`, `dotnet9`, `csharp12`, `automation`

    ---

    ```
*   The original `data.json` will be gone (it's been archived).

---

**Modularity and Future Enhancements:**

*   **Changing Parsers/Converters:**
    *   You can create a new class `AlternativeJsonProcessor : IJsonProcessor<AnotherModel>` and `AlternativeMarkdownConverter : IMarkdownConverter<AnotherModel>`.
    *   Then, in `Program.cs`, you'd instantiate these new classes. If the model changes, you'd adjust `AppLogic` or make it generic.
*   **Changing File Operations:**
    *   If you want to store archives in Azure Blob Storage, you could create `AzureBlobStorageArchiver : IFileArchiver`.
*   **Dependency Injection Framework:** For larger applications, you'd use a DI framework like `Microsoft.Extensions.DependencyInjection`. You'd register your services (`services.AddSingleton<IJsonProcessor<JsonContent>, DefaultJsonProcessor>();`) and resolve `AppLogic` from the service provider.
*   **Packaging:**
    *   **Class Libraries:** The `Core`, `Models`, and `Services` could be moved into separate Class Library projects (`.csproj`). The main CLI project would then reference these libraries. This is the first step towards NuGet packages.
    *   **NuGet Packages:** Once you have separate class libraries, you can pack them into NuGet packages using `dotnet pack`. This is useful if these components are to be shared across multiple applications.
*   **Error Handling:** The current error handling is basic (console output). For a production tool, more robust logging (e.g., Serilog, NLog) and potentially custom exceptions would be better.
*   **Configuration:** More complex settings could be moved to a configuration file (e.g., `appsettings.json`).

This structure provides a solid foundation for building a robust and extensible CLI tool. You can now easily swap out or add new implementations for parsing, conversion, or file handling by creating new classes that implement the defined interfaces.
