## Rust CLI program: Appender 

We'll use the `walkdir` crate for directory traversal, `regex` for pattern matching, and standard library file I/O.

**Step 1: Set up the Rust Project**

1.  **Create a new Rust project:**
    ```bash
    cargo new file_appender_cli
    cd file_appender_cli
    ```

2.  **Add dependencies to `Cargo.toml`:**
    We'll need `walkdir` for recursive directory walking, `regex` for pattern matching, and `clap` for command-line argument parsing.

    Open `Cargo.toml` and add the following under `[dependencies]`:
    ```toml
    [package]
    name = "file_appender_cli"
    version = "0.1.0"
    edition = "2021"

    # See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

    [dependencies]
    walkdir = "2.4.0"  # Check crates.io for the latest version
    regex = "1.10.3"   # Check crates.io for the latest version
    clap = { version = "4.5.1", features = ["derive"] } # Check crates.io
    thiserror = "1.0.57" # For cleaner error handling
    ```
    *   `walkdir`: For walking directory trees.
    *   `regex`: For regular expression matching on filenames.
    *   `clap`: For robust command-line argument parsing.
    *   `thiserror`: A utility for creating custom error types easily.

**Step 2: Define Custom Errors (Optional but Recommended)**

Create `src/errors.rs` for custom error types:

```rust
// src/errors.rs
use std::io;
use std::path::PathBuf;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppenderError {
    #[error("IO error: {0}")]
    Io(#[from] io::Error),

    #[error("Regex compilation error: {0}")]
    Regex(#[from] regex::Error),

    #[error("Walkdir error: {0}")]
    WalkDir(#[from] walkdir::Error),

    #[error("Failed to convert OsStr to String for path: {0:?}")]
    PathConversion(PathBuf),

    #[error("Data file not found: {0:?}")]
    DataFileNotFound(PathBuf),

    #[error("Failed to append to file {path:?}: {source}")]
    AppendFailed {
        path: PathBuf,
        #[source]
        source: io::Error,
    },

    #[error("Source directory not found or is not a directory: {0:?}")]
    SourceDirInvalid(PathBuf),
}
```

Then, in `src/main.rs`, add `mod errors;` at the top.

**Step 3: Write the Core Logic in `src/main.rs`**

```rust
// src/main.rs
mod errors; // Import our custom errors module

use errors::AppenderError;
use clap::Parser;
use regex::Regex;
use std::fs::{self, OpenOptions};
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

/// CLI tool to append content from a data file to files matching a regex pattern in a directory.
#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Cli {
    /// The directory to walk through.
    #[clap(short, long, value_parser)]
    directory: PathBuf,

    /// Regex pattern to match filenames (e.g., "^Oxide.*\\.txt$").
    /// Note: Shells might interpret *, so quote it: "^Oxide.*\\.txt$"
    #[clap(short, long, value_parser)]
    pattern: String,

    /// Path to the data file whose content will be appended.
    #[clap(short, long, value_parser, default_value = "data.md")]
    data_file: PathBuf,
}

fn main() -> Result<(), AppenderError> {
    let cli = Cli::parse();

    // 1. Validate source directory
    if !cli.directory.exists() || !cli.directory.is_dir() {
        return Err(AppenderError::SourceDirInvalid(cli.directory));
    }
    println!("Searching in directory: {:?}", cli.directory);


    // 2. Read the content to append from data_file
    if !cli.data_file.exists() {
        return Err(AppenderError::DataFileNotFound(cli.data_file));
    }
    let data_to_append = fs::read_to_string(&cli.data_file)
        .map_err(|e| AppenderError::Io(e))?; // Can also use .map_err(AppenderError::Io)?
    println!("Successfully read data from: {:?}", cli.data_file);
    if data_to_append.is_empty() {
        println!("Warning: Data file {:?} is empty. Nothing will be appended.", cli.data_file);
    }


    // 3. Compile the regex pattern
    let re = Regex::new(&cli.pattern).map_err(AppenderError::Regex)?;
    println!("Using regex pattern: {}", cli.pattern);

    let mut files_processed_count = 0;

    // 4. Walk the directory
    for entry_result in WalkDir::new(&cli.directory) {
        let entry = entry_result.map_err(AppenderError::WalkDir)?;
        let path = entry.path();

        if path.is_file() {
            if let Some(filename_osstr) = path.file_name() {
                if let Some(filename_str) = filename_osstr.to_str() {
                    if re.is_match(filename_str) {
                        println!("Found matching file: {:?}", path);
                        match append_to_file(path, &data_to_append) {
                            Ok(_) => {
                                println!("Successfully appended to {:?}", path);
                                files_processed_count += 1;
                            }
                            Err(e) => {
                                eprintln!("Error appending to file {:?}: {}", path, e);
                                // Decide if you want to stop or continue on error
                                // For this example, we'll print an error and continue
                            }
                        }
                    }
                } else {
                    eprintln!("Warning: Could not convert filename to string for path: {:?}", path);
                }
            }
        }
    }

    println!("\nFinished processing. Appended data to {} file(s).", files_processed_count);
    Ok(())
}

/// Appends the given content to the specified file.
fn append_to_file(file_path: &Path, content: &str) -> Result<(), AppenderError> {
    let mut file = OpenOptions::new()
        .append(true)
        .open(file_path)
        .map_err(|e| AppenderError::AppendFailed { path: file_path.to_path_buf(), source: e })?;

    file.write_all(content.as_bytes())
        .map_err(|e| AppenderError::AppendFailed { path: file_path.to_path_buf(), source: e })?;
    
    // Optionally, add a newline if the data_to_append doesn't end with one
    // and you want to ensure separation.
    // if !content.ends_with('\n') {
    //     file.write_all(b"\n")
    //         .map_err(|e| AppenderError::AppendFailed { path: file_path.to_path_buf(), source: e })?;
    // }
    
    Ok(())
}
```

**Explanation of `src/main.rs`:**

1.  **`Cli` struct:** Uses `clap` derive macros to define command-line arguments:
    *   `directory`: The target directory to search.
    *   `pattern`: The regex pattern for filenames (e.g., `"^Oxide.*"` will match files starting with "Oxide").
    *   `data_file`: The file containing the data to append (defaults to "data.md").
2.  **`main` function:**
    *   Parses CLI arguments using `Cli::parse()`.
    *   Validates the source directory.
    *   Reads the content from `data_file` into `data_to_append`.
    *   Compiles the provided `pattern` into a `Regex` object.
    *   Uses `WalkDir::new()` to iterate over all entries in the specified directory recursively.
    *   For each entry:
        *   Checks if it's a file.
        *   Gets the filename.
        *   Checks if the filename matches the compiled regex.
        *   If it matches, calls `append_to_file`.
    *   Prints progress and a summary.
3.  **`append_to_file` function:**
    *   Opens the target file in append mode (`OpenOptions::new().append(true)`).
    *   Writes the `content` to the end of the file.
    *   Returns `Ok(())` on success or an `AppenderError` on failure.

**Step 4: Prepare for Testing**

1.  **Create a test directory structure and sample files:**
    In your project's root directory (`file_appender_cli/`), create:
    *   A file named `data.md`:
        ```markdown
        ---
        appended_by: rust_cli_tool
        timestamp: $(date +%s)
        ---
        This is the content to be appended.
        It can span multiple lines.
        ```
    *   A directory for testing, e.g., `test_dir/`:
        ```bash
        mkdir test_dir
        mkdir test_dir/subdir
        ```
    *   Files inside `test_dir/` that should match and some that shouldn't:
        ```bash
        # test_dir/OxideReport_alpha.txt
        echo "Initial content for OxideReport_alpha." > test_dir/OxideReport_alpha.txt

        # test_dir/OxideLog_beta.log
        echo "Log data for OxideLog_beta." > test_dir/OxideLog_beta.log

        # test_dir/NonMatchingFile.txt
        echo "This file should not be modified." > test_dir/NonMatchingFile.txt

        # test_dir/subdir/OxideData_gamma.md
        echo "Content in subdir for OxideData_gamma." > test_dir/subdir/OxideData_gamma.md

        # test_dir/subdir/AnotherFile.dat
        echo "Another file, should not match." > test_dir/subdir/AnotherFile.dat
        ```

**Step 5: Build and Run the Program**

1.  **Build the program:**
    ```bash
    cargo build
    ```
    For a release build (optimized):
    ```bash
    cargo build --release
    ```
    The executable will be in `target/debug/file_appender_cli` or `target/release/file_appender_cli`.

2.  **Run the program:**
    Let's say your current directory is `file_appender_cli/`.

    ```bash
    # Using debug build
    ./target/debug/file_appender_cli --directory ./test_dir --pattern "^Oxide.*" --data-file ./data.md

    # Or using release build
    # ./target/release/file_appender_cli -d ./test_dir -p "^Oxide.*" -f ./data.md
    ```

    **Important Note on Regex and Shells:**
    If your pattern contains characters like `*`, `?`, `[`, `]`, your shell might try to interpret them (globbing). It's best to quote the pattern:
    `--pattern "^Oxide.*"` or `--pattern '^Oxide.*'`

    **Expected Output:**
    ```
    Searching in directory: "./test_dir"
    Successfully read data from: "./data.md"
    Using regex pattern: ^Oxide.*
    Found matching file: "./test_dir/OxideReport_alpha.txt"
    Successfully appended to "./test_dir/OxideReport_alpha.txt"
    Found matching file: "./test_dir/OxideLog_beta.log"
    Successfully appended to "./test_dir/OxideLog_beta.log"
    Found matching file: "./test_dir/subdir/OxideData_gamma.md"
    Successfully appended to "./test_dir/subdir/OxideData_gamma.md"

    Finished processing. Appended data to 3 file(s).
    ```

3.  **Verify the changes:**
    Check the content of the `Oxide*` files in `test_dir/` and `test_dir/subdir/`. They should now have the content of `data.md` appended to them. `NonMatchingFile.txt` and `AnotherFile.dat` should be unchanged.

    For example, `test_dir/OxideReport_alpha.txt` would look like:
    ```
    Initial content for OxideReport_alpha.
    ---
    appended_by: rust_cli_tool
    timestamp: 1678886400 # example timestamp
    ---
    This is the content to be appended.
    It can span multiple lines.
    ```

**Step 6: Writing Tests (Integration Tests)**

Rust's testing framework is great. We'll write an integration test.

1.  Create a directory `tests/` in your project root (`file_appender_cli/tests/`).
2.  Create a file `tests/cli_integration_test.rs`:

    ```rust
    // tests/cli_integration_test.rs
    use std::fs::{self, File};
    use std::io::Write;
    use std::path::PathBuf;
    use std::process::Command;
    use assert_cmd::prelude::*; // Add `assert_cmd` to your dev-dependencies
    use predicates::prelude::*; // Add `predicates` to your dev-dependencies
    use tempfile::tempdir; // Add `tempfile` to your dev-dependencies

    // Helper function to get the path to the compiled binary
    fn get_binary_path() -> PathBuf {
        let mut path = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        path.push("target");
        path.push(if cfg!(debug_assertions) { "debug" } else { "release" });
        path.push("file_appender_cli"); // Your binary name
        path
    }

    #[test]
    fn test_append_to_matching_files() -> Result<(), Box<dyn std::error::Error>> {
        let temp_dir = tempdir()?; // Create a temporary directory for the test
        let base_path = temp_dir.path();

        // 1. Create data.md
        let data_md_path = base_path.join("test_data.md");
        let mut data_file = File::create(&data_md_path)?;
        let append_content = "---\nAppended Content\n---\n";
        writeln!(data_file, "{}", append_content)?;

        // 2. Create test directory structure and files
        let target_dir = base_path.join("my_files");
        fs::create_dir_all(target_dir.join("subdir"))?;

        let file1_path = target_dir.join("OxideFile1.txt");
        let file1_initial_content = "Initial content for File1.\n";
        fs::write(&file1_path, file1_initial_content)?;

        let file2_path = target_dir.join("subdir/OxideData2.log");
        let file2_initial_content = "Log for Data2.\n";
        fs::write(&file2_path, file2_initial_content)?;

        let non_matching_file_path = target_dir.join("OtherFile.txt");
        let non_matching_initial_content = "Should not be touched.\n";
        fs::write(&non_matching_file_path, non_matching_initial_content)?;

        // 3. Run the CLI command
        let mut cmd = Command::new(get_binary_path());
        cmd.arg("--directory")
            .arg(&target_dir)
            .arg("--pattern")
            .arg("^Oxide.*") // Regex pattern
            .arg("--data-file")
            .arg(&data_md_path);

        cmd.assert()
            .success()
            .stdout(predicate::str::contains("Appended data to 2 file(s)."));

        // 4. Verify file contents
        let file1_content_after = fs::read_to_string(&file1_path)?;
        let expected_file1_content = format!("{}{}", file1_initial_content, append_content);
        assert_eq!(file1_content_after.trim_end(), expected_file1_content.trim_end()); // trim_end for potential newline differences

        let file2_content_after = fs::read_to_string(&file2_path)?;
        let expected_file2_content = format!("{}{}", file2_initial_content, append_content);
        assert_eq!(file2_content_after.trim_end(), expected_file2_content.trim_end());

        let non_matching_content_after = fs::read_to_string(&non_matching_file_path)?;
        assert_eq!(non_matching_content_after, non_matching_initial_content);
        
        // The temp_dir (and its contents) will be automatically cleaned up when it goes out of scope
        Ok(())
    }

    #[test]
    fn test_data_file_not_found() -> Result<(), Box<dyn std::error::Error>> {
        let temp_dir = tempdir()?;
        let base_path = temp_dir.path();
        let target_dir = base_path.join("my_files");
        fs::create_dir(&target_dir)?; // Create an empty directory

        let mut cmd = Command::new(get_binary_path());
        cmd.arg("--directory")
           .arg(&target_dir)
           .arg("--pattern")
           .arg("^Oxide.*")
           .arg("--data-file")
           .arg(base_path.join("non_existent_data.md")); // Non-existent data file

        cmd.assert()
            .failure() // Expect the command to fail
            .stderr(predicate::str::contains("Data file not found"));
        Ok(())
    }

    #[test]
    fn test_source_directory_not_found() -> Result<(), Box<dyn std::error::Error>> {
        let temp_dir = tempdir()?;
        let base_path = temp_dir.path();
        
        // Create a dummy data.md so that part doesn't fail first
        let data_md_path = base_path.join("dummy_data.md");
        fs::write(&data_md_path, "dummy content")?;

        let mut cmd = Command::new(get_binary_path());
        cmd.arg("--directory")
           .arg(base_path.join("non_existent_dir")) // Non-existent source directory
           .arg("--pattern")
           .arg("^Oxide.*")
           .arg("--data-file")
           .arg(&data_md_path);

        cmd.assert()
            .failure()
            .stderr(predicate::str::contains("Source directory not found"));
        Ok(())
    }
    ```

3.  **Add test dependencies to `Cargo.toml`:**
    ```toml
    [dev-dependencies]
    assert_cmd = "2.0.13"
    predicates = "3.1.0"
    tempfile = "3.10.1"
    ```
    Make sure to check crates.io for the latest versions.

4.  **Run the tests:**
    ```bash
    cargo test
    ```
    This will compile your main program and the test suite, then execute the tests.

**Best Practices Used and Azure Context:**

*   **Clear CLI Interface (`clap`):** Makes the tool user-friendly and self-documenting (`--help`).
*   **Robust Error Handling (`thiserror`):** Provides meaningful error messages.
*   **Efficient Directory Traversal (`walkdir`):** Suitable for deep directory structures.
*   **Precise File Matching (`regex`):** Offers flexibility in defining which files to target.
*   **Idempotency (Partial):** If you run the tool multiple times, it will append the content multiple times. If this is not desired, you'd need to add logic to check if the content has already been appended (e.g., by adding a unique marker string and checking for its presence before appending).
*   **Integration Tests:** Ensure the tool works as expected end-to-end.
*   **Cross-Platform:** Rust compiles to native binaries, making it portable.
*   **Azure Cloud Relevance:**
    *   **Data Preprocessing:** This tool can be part of a pipeline to prepare files locally before uploading them to Azure Blob Storage, Azure Files, or processing them with Azure Functions or Azure Batch. For instance, you might need to add metadata or common footers to log files or configuration files.
    *   **Configuration Management:** If you manage configuration files that need standardized sections, this tool can automate adding them.
    *   **Local Development for Azure Projects:** When developing applications that will run on Azure, you often need local tools for tasks like this.

**Further Enhancements:**

*   **Concurrency:** For very large numbers of files or very large directories, you could explore using `rayon` to process files in parallel.
*   **Idempotency Check:** Add a unique string or comment to `data.md` and check if it already exists in the target file before appending.
*   **Verbose/Quiet Mode:** Add flags to control the amount of output.
*   **Dry Run Mode:** A flag to show what files *would* be modified without actually changing them.
*   **Backup Option:** Before modifying a file, create a backup copy.

This comprehensive solution provides a robust Rust CLI tool with good practices and testing. Remember to adjust the regex pattern in `--pattern` to precisely match your "Oxide*" requirement (e.g., `^Oxide.*` for files starting with "Oxide", or `^Oxide[^/]*$` if you don't want it to match directory names that might coincidentally start with Oxide if the pattern was too loose, though `path.is_file()` already handles this).
