## CSharp Options flag 

Let's Add a new command-line flag:

**1. Update `Program.cs` to include the `--replace` flag:**

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
            getDefaultValue: () => new FileInfo("data.json"));

        var targetDirOption = new Option<DirectoryInfo>(
            name: "--target-directory",
            description: "The directory to search for the target Markdown file.",
            getDefaultValue: () => new DirectoryInfo("."));

        var targetPatternOption = new Option<string>(
            name: "--target-pattern",
            description: "Regex pattern to find the target Markdown file (e.g., \"^README.*\\.md$\").",
            getDefaultValue: () => "^NOTES.*\\.md$");

        var archiveSubDirOption = new Option<string?>(
            name: "--archive-subdir",
            description: "Optional subdirectory within the source/target file's directory to move archived files to.");

        var replaceOption = new Option<bool>( // New option
            name: "--replace",
            description: "If set, the target file's content will be replaced instead of appended.",
            getDefaultValue: () => false); // Default to false (append mode)

        var rootCommand = new RootCommand("CLI tool to parse JSON, convert to Markdown, and append/replace content in a file.");
        rootCommand.AddOption(jsonFileOption);
        rootCommand.AddOption(targetDirOption);
        rootCommand.AddOption(targetPatternOption);
        rootCommand.AddOption(archiveSubDirOption);
        rootCommand.AddOption(replaceOption); // Add new option to the command

        rootCommand.SetHandler(async (jsonFile, targetDir, targetPattern, archiveSubDir, replace) => // Add 'replace' parameter
        {
            // Simple Dependency Injection setup (manual for now)
            IJsonProcessor<JsonContent> jsonProcessor = new DefaultJsonProcessor();
            IMarkdownConverter<JsonContent> markdownConverter = new SimpleMarkdownConverter();
            IFileFinder fileFinder = new RegexFileFinder();
            IFileArchiver fileArchiver = new TimestampFileArchiver();
            // IFileWriter fileWriter = new DefaultFileWriter(); // We'll use File.WriteAllTextAsync directly in AppLogic now

            var appLogic = new AppLogic(
                jsonProcessor,
                markdownConverter,
                fileFinder,
                fileArchiver
                // fileWriter // Removed from AppLogic constructor
                );

            await appLogic.RunAsync(jsonFile.FullName, targetDir.FullName, targetPattern, archiveSubDir, replace); // Pass 'replace' flag

        }, jsonFileOption, targetDirOption, targetPatternOption, archiveSubDirOption, replaceOption); // Pass option to handler

        return await rootCommand.InvokeAsync(args);
    }
}
```
**Changes in `Program.cs`:**
*   Added a `replaceOption` of type `Option<bool>`.
*   Set its `getDefaultValue` to `false`, so appending is the default behavior.
*   Added the `replaceOption` to the `rootCommand`.
*   Updated the `SetHandler` lambda to accept the `replace` boolean value.
*   Commented out `IFileWriter` instantiation and passing to `AppLogic` as we'll handle file writing directly in `AppLogic` for more control over append/replace.

---

**2. Update `AppLogic.cs` to handle the `replace` flag:**

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
    IFileArchiver fileArchiver) // Removed IFileWriter from constructor
{
    public async Task<int> RunAsync(
        string jsonFilePath,
        string targetDirectory,
        string targetFilePattern,
        string? archiveSubDir,
        bool replaceMode) // New parameter for replace mode
    {
        Console.WriteLine($"Processing JSON file: {jsonFilePath}");
        Console.WriteLine($"Target directory: {targetDirectory}");
        Console.WriteLine($"Target file pattern: {targetFilePattern}");
        Console.WriteLine($"Operation mode: {(replaceMode ? "Replace" : "Append")}"); // Indicate mode
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
            return 1;
        }

        // 2. Convert to Markdown
        string newMarkdownContent = markdownConverter.Convert(jsonData);
        if (string.IsNullOrEmpty(newMarkdownContent) && !replaceMode) // If replacing, empty content is valid for replacement.
        {
            Console.WriteLine("Generated Markdown content is empty. No content to append.");
            await fileArchiver.ArchiveAsync(jsonFilePath, archiveSubDir);
            Console.WriteLine("---");
            Console.WriteLine("Operation completed (no content to append/replace).");
            return 0;
        }
        else if (string.IsNullOrEmpty(newMarkdownContent) && replaceMode)
        {
            Console.WriteLine("Generated Markdown content is empty. Target file will be replaced with empty content (if found and archived).");
        }


        // 3. Find target Markdown file
        string? existingTargetFilePath = fileFinder.FindFile(targetDirectory, targetFilePattern);
        string finalTargetFilePath;
        string contentToWrite;

        if (existingTargetFilePath != null)
        {
            Console.WriteLine($"Found target file: {existingTargetFilePath}");
            finalTargetFilePath = existingTargetFilePath; // We will write back to the original name

            string originalTargetContent = string.Empty;
            if (!replaceMode) // Only read original content if in append mode
            {
                try
                {
                    originalTargetContent = await File.ReadAllTextAsync(existingTargetFilePath);
                    if (!string.IsNullOrEmpty(originalTargetContent) && !originalTargetContent.EndsWith(Environment.NewLine))
                    {
                        originalTargetContent += Environment.NewLine;
                    }
                }
                catch (FileNotFoundException)
                {
                    Console.WriteLine($"Info: Target file '{existingTargetFilePath}' disappeared before reading. Treating as new file for append.");
                    originalTargetContent = string.Empty; // Continue as if file was not found for reading
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"Error reading existing target file for append '{existingTargetFilePath}': {ex.Message}");
                    // Depending on strictness, you might want to abort here.
                    // For now, we'll proceed, potentially overwriting if the read failed but file exists.
                    // Or, treat as if content is empty for append.
                    originalTargetContent = string.Empty;
                }
            }

            // 4. Archive existing target Markdown file (happens for both append and replace if file exists)
            await fileArchiver.ArchiveAsync(existingTargetFilePath, archiveSubDir);

            if (replaceMode)
            {
                contentToWrite = newMarkdownContent;
            }
            else // Append mode
            {
                contentToWrite = originalTargetContent + newMarkdownContent;
            }
        }
        else // Target file not found
        {
            string baseName = targetFilePattern.TrimStart('^')
                                             .Replace(".*", "")
                                             .Replace("\\.md$", ".md", StringComparison.OrdinalIgnoreCase)
                                             .Split('.')[0];
            if (string.IsNullOrWhiteSpace(baseName)) baseName = "output";
            if (!baseName.EndsWith(".md", StringComparison.OrdinalIgnoreCase)) baseName += ".md";
            
            finalTargetFilePath = Path.Combine(targetDirectory, baseName);
            Console.WriteLine($"No target file found matching pattern. Will create: {finalTargetFilePath}");
            contentToWrite = newMarkdownContent; // If file doesn't exist, append and replace are effectively the same: write new content.
        }

        // 5. Write the content (either new, or combined old+new)
        try
        {
            string? directory = Path.GetDirectoryName(finalTargetFilePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }
            await File.WriteAllTextAsync(finalTargetFilePath, contentToWrite);
            Console.WriteLine($"Successfully wrote content to '{finalTargetFilePath}'.");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"Error writing content to file '{finalTargetFilePath}': {ex.Message}");
            return 1; // Error
        }

        // 6. Archive source JSON file
        await fileArchiver.ArchiveAsync(jsonFilePath, archiveSubDir);
        
        Console.WriteLine("---");
        Console.WriteLine("Operation completed successfully.");
        return 0; // Success
    }
}
```

**Changes in `AppLogic.cs`:**
*   The constructor no longer takes `IFileWriter`.
*   `RunAsync` now accepts a `bool replaceMode` parameter.
*   **Conditional Content Reading:** The content of `existingTargetFilePath` is only read if `!replaceMode` (i.e., we are in append mode).
*   **Archiving Target:** The `existingTargetFilePath` is archived if it exists, *regardless* of `replaceMode`. This is correct, as in both cases, the original state before this operation is being preserved.
*   **Determining `contentToWrite`:**
    *   If `replaceMode` is true, `contentToWrite` is just `newMarkdownContent`.
    *   If `replaceMode` is false (append), `contentToWrite` is `originalTargetContent + newMarkdownContent`.
    *   If the target file wasn't found, `contentToWrite` is `newMarkdownContent` (as there's nothing to append to or replace from).
*   **File Writing:** `File.WriteAllTextAsync(finalTargetFilePath, contentToWrite)` is used to write the determined content. This naturally handles both creating a new file and overwriting an existing one with the new (or combined) content.

---

**How to Test:**

1.  **Ensure `data.json` and `NOTES.md` exist.**
    `NOTES.md`:
    ```markdown
    # Original Project Notes
    
    Some initial content.
    ---
    ```
    `data.json`:
    ```json
    {
      "title": "Feature Update",
      "paragraphs": ["Added append/replace modes."]
    }
    ```

2.  **Build:**
    ```bash
    dotnet build
    ```

3.  **Test Append Mode (default):**
    ```bash
    dotnet run
    ```
    *   `NOTES.md` should be archived as `NOTES_<timestamp>.md` (containing "Original Project Notes").
    *   `data.json` should be archived.
    *   The new `NOTES.md` should contain:
        ```markdown
        # Original Project Notes
        
        Some initial content.
        ---
        ## Feature Update

        Added append/replace modes.

        ---
        
        ```

4.  **Prepare for Replace Test:**
    *   Modify `data.json` again for different content:
        ```json
        {
          "title": "Complete Replacement",
          "author": "Admin",
          "paragraphs": ["This content fully replaces the old file."]
        }
        ```
    *   The `NOTES.md` currently has the appended content from the previous step.

5.  **Test Replace Mode:**
    ```bash
    dotnet run --replace
    ```
    *   The current `NOTES.md` (with "Feature Update" appended) should be archived as `NOTES_<new_timestamp>.md`.
    *   `data.json` should be archived.
    *   The new `NOTES.md` should *only* contain:
        ```markdown
        ## Complete Replacement
        _By: Admin_

        This content fully replaces the old file.

        ---
        
        ```

This structure provides the flexibility you were looking for, defaulting to the safer "append" operation while allowing for a full "replace" when needed.
