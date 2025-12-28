## C CLI program to Append 

We'll use standard C libraries for directory traversal (`dirent.h`), POSIX regular expressions (`regex.h`), and file I/O (`stdio.h`).

**Project Structure:**

```
file_appender_c/
├── src/
│   └── main.c
├── Makefile
├── data.md        # Sample data file to append
└── test_dir/      # Directory for testing
    ├── OxideFile1.txt
    ├── OxideLog2.doc
    ├── NonOxideFile.txt
    └── subdir/
        └── OxideData3.md
```

**Step 1: Set up the Project Directory and Files**

1.  Create the project directory:
    ```bash
    mkdir file_appender_c
    cd file_appender_c
    mkdir src
    mkdir test_dir
    mkdir test_dir/subdir
    ```

2.  Create `src/main.c`. We'll populate this next.

3.  Create a sample `data.md` file in the `file_appender_c` directory:
    ```bash
    echo "--- Appended Content ---" > data.md
    echo "Timestamp: $(date)" >> data.md
    echo "Source: C_CLI_Appender" >> data.md
    echo "------------------------" >> data.md
    ```

4.  Create sample files in `test_dir/`:
    ```bash
    echo "Initial content for OxideFile1." > test_dir/OxideFile1.txt
    echo "Initial content for OxideLog2." > test_dir/OxideLog2.doc
    echo "This file should not be touched." > test_dir/NonOxideFile.txt
    echo "Content in subdir for OxideData3." > test_dir/subdir/OxideData3.md
    ```

**Step 2: Write the C Code (`src/main.c`)**

```c
// src/main.c
#define _POSIX_C_SOURCE 200809L // For nftw, getline
#define _DEFAULT_SOURCE         // For DT_DIR, DT_REG with some glibc versions
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <regex.h>
#include <limits.h> // For PATH_MAX (though its use is debated, we'll be careful)
#include <errno.h>

#define MAX_PATH_LEN 4096 // A reasonable buffer size for paths

// Global buffer for data.md content
char *data_to_append = NULL;
long data_to_append_size = 0;
int files_processed_count = 0;

// Forward declaration
void process_directory(const char *dir_path, const char *file_pattern_str, regex_t *regex_pattern);

// Function to read the entire content of data_file into a global buffer
int load_data_to_append(const char *data_file_path) {
    FILE *f = fopen(data_file_path, "rb"); // Open in binary read mode
    if (!f) {
        perror("Error opening data file");
        return -1;
    }

    fseek(f, 0, SEEK_END);
    data_to_append_size = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (data_to_append_size == 0) {
        fprintf(stderr, "Warning: Data file '%s' is empty. Nothing will be appended.\n", data_file_path);
        fclose(f);
        // Still "success" in loading, but content is empty.
        // Allocate a single null terminator for safety if other code assumes it's a C-string.
        data_to_append = (char *)malloc(1);
        if (!data_to_append) {
            perror("Failed to allocate memory for empty data buffer");
            return -1;
        }
        data_to_append[0] = '\0';
        return 0;
    }


    data_to_append = (char *)malloc(data_to_append_size + 1); // +1 for null terminator if used as string
    if (!data_to_append) {
        perror("Error allocating memory for data file content");
        fclose(f);
        return -1;
    }

    if (fread(data_to_append, 1, data_to_append_size, f) != (size_t)data_to_append_size) {
        perror("Error reading data file content");
        free(data_to_append);
        data_to_append = NULL;
        fclose(f);
        return -1;
    }
    data_to_append[data_to_append_size] = '\0'; // Null-terminate for safety, though fwrite won't use it

    fclose(f);
    printf("Successfully read %ld bytes from: %s\n", data_to_append_size, data_file_path);
    return 0;
}

// Function to append data to a file
void append_to_file(const char *file_path) {
    if (!data_to_append || data_to_append_size == 0) {
        // This case is handled if data_file was empty, but as an extra check
        printf("Skipping append for %s: no data to append.\n", file_path);
        return;
    }

    FILE *f = fopen(file_path, "ab"); // Open in append binary mode
    if (!f) {
        fprintf(stderr, "Error opening file %s for appending: %s\n", file_path, strerror(errno));
        return;
    }

    // Add a newline before appending if data doesn't start with one, and file might not end with one.
    // This is optional, adjust as needed.
    // For simplicity, we'll just append. If consistent newlines are critical,
    // check the last char of the file or ensure data_to_append starts with \n.
    // fseek(f, -1, SEEK_END);
    // if (fgetc(f) != '\n') {
    //    fwrite("\n", 1, 1, f);
    // }
    // fseek(f, 0, SEEK_END); // Go back to end for appending

    if (fwrite(data_to_append, 1, data_to_append_size, f) != (size_t)data_to_append_size) {
        fprintf(stderr, "Error writing to file %s: %s\n", file_path, strerror(errno));
    } else {
        printf("Successfully appended to %s\n", file_path);
        files_processed_count++;
    }
    fclose(f);
}

// Function to process a directory
void process_directory(const char *dir_path, const char *file_pattern_str, regex_t *regex_pattern) {
    DIR *dir = opendir(dir_path);
    if (!dir) {
        fprintf(stderr, "Error opening directory %s: %s\n", dir_path, strerror(errno));
        return;
    }

    struct dirent *entry;
    char full_path[MAX_PATH_LEN];

    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        snprintf(full_path, sizeof(full_path), "%s/%s", dir_path, entry->d_name);

        struct stat entry_stat;
        if (stat(full_path, &entry_stat) == -1) {
            fprintf(stderr, "Error getting stat for %s: %s\n", full_path, strerror(errno));
            continue;
        }

        if (S_ISDIR(entry_stat.st_mode)) { // It's a directory
            process_directory(full_path, file_pattern_str, regex_pattern);
        } else if (S_ISREG(entry_stat.st_mode)) { // It's a regular file
            // Check if filename matches the regex pattern
            if (regexec(regex_pattern, entry->d_name, 0, NULL, 0) == 0) {
                printf("Found matching file: %s\n", full_path);
                append_to_file(full_path);
            }
        }
    }
    closedir(dir);
}

int main(int argc, char *argv[]) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <directory> <filename-regex-pattern> <data-file>\n", argv[0]);
        fprintf(stderr, "Example: %s ./test_dir \"^Oxide.*\" ./data.md\n", argv[0]);
        return 1;
    }

    const char *target_directory = argv[1];
    const char *file_pattern_str = argv[2];
    const char *data_file_path = argv[3];

    // Validate target directory
    struct stat dir_stat;
    if (stat(target_directory, &dir_stat) == -1 || !S_ISDIR(dir_stat.st_mode)) {
        fprintf(stderr, "Error: Target directory '%s' not found or is not a directory.\n", target_directory);
        return 1;
    }
    printf("Searching in directory: %s\n", target_directory);

    // Load data to append
    if (load_data_to_append(data_file_path) != 0) {
        return 1; // Error message already printed by load_data_to_append
    }
    if (data_to_append == NULL && data_to_append_size > 0) { // Malloc failed but size was positive
        fprintf(stderr, "Failed to load data, exiting.\n");
        return 1;
    }


    // Compile the regex pattern
    regex_t regex_pattern;
    int reti = regcomp(&regex_pattern, file_pattern_str, REG_EXTENDED | REG_NOSUB);
    if (reti) {
        char errbuf[100];
        regerror(reti, &regex_pattern, errbuf, sizeof(errbuf));
        fprintf(stderr, "Could not compile regex '%s': %s\n", file_pattern_str, errbuf);
        if (data_to_append) free(data_to_append);
        return 1;
    }
    printf("Using regex pattern: %s\n", file_pattern_str);

    // Process the directory
    process_directory(target_directory, file_pattern_str, &regex_pattern);

    // Cleanup
    regfree(&regex_pattern);
    if (data_to_append) {
        free(data_to_append);
        data_to_append = NULL;
    }

    printf("\nFinished processing. Appended data to %d file(s).\n", files_processed_count);
    return 0;
}
```

**Key points in `main.c`:**

*   **Includes:** Standard headers for I/O, strings, directory operations, file status, and regular expressions.
*   `MAX_PATH_LEN`: A defined maximum path length. Be cautious with this; dynamically allocated paths are safer for arbitrary depths, but `snprintf` helps prevent overflows here.
*   `load_data_to_append()`: Reads the entire content of the `data-file` into a dynamically allocated global buffer `data_to_append`.
*   `append_to_file()`: Opens a file in append binary mode (`"ab"`) and writes the `data_to_append` buffer to it.
*   `process_directory()`:
    *   Uses `opendir`, `readdir`, `closedir` to iterate through directory entries.
    *   Uses `stat` to determine if an entry is a directory or a regular file.
    *   Recursively calls itself for subdirectories.
    *   For files, it uses `regexec` to match the filename against the compiled `regex_pattern`.
    *   Constructs full paths using `snprintf`.
*   `main()`:
    *   Parses command-line arguments: directory, regex pattern, data file path.
    *   Validates the target directory.
    *   Calls `load_data_to_append()`.
    *   Compiles the regex pattern using `regcomp` with `REG_EXTENDED` (for modern regex syntax) and `REG_NOSUB` (as we only care about matching, not capturing groups, for a slight optimization).
    *   Calls `process_directory()` to start the traversal.
    *   Frees allocated memory (`data_to_append` and `regex_t`).

**Step 3: Create the `Makefile`**

In the `file_appender_c` directory, create a `Makefile`:

```makefile
# Makefile
CC = gcc
CFLAGS = -Wall -Wextra -std=c11 -g # -g for debugging symbols
LDFLAGS = # No special linker flags needed for regex on most modern systems

TARGET_EXEC = file_appender
SRC_DIR = src
BUILD_DIR = build
SOURCES = $(SRC_DIR)/main.c
OBJECTS = $(BUILD_DIR)/main.o

.PHONY: all clean test

all: $(BUILD_DIR)/$(TARGET_EXEC)

$(BUILD_DIR)/$(TARGET_EXEC): $(OBJECTS)
	@mkdir -p $(@D) # Ensure build directory for the executable exists
	$(CC) $(OBJECTS) -o $@ $(LDFLAGS)
	@echo "Build complete: $@"

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(@D) # Ensure build directory for object files exists
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	@echo "Cleaning up..."
	@rm -rf $(BUILD_DIR)
	@echo "Clean complete."

# A simple test "target" that just runs the compiled program with sample data.
# This is not a full unit/integration test suite, but a convenience.
test: all
	@echo "Running test scenario..."
	@echo "Initial state of test_dir/OxideFile1.txt:"
	@cat test_dir/OxideFile1.txt || true
	./$(BUILD_DIR)/$(TARGET_EXEC) ./test_dir "^Oxide.*" ./data.md
	@echo "\nState of test_dir/OxideFile1.txt after running:"
	@cat test_dir/OxideFile1.txt || true
	@echo "\nState of test_dir/NonOxideFile.txt after running (should be unchanged):"
	@cat test_dir/NonOxideFile.txt || true
	@echo "\nTest run finished. Manually verify other files like test_dir/subdir/OxideData3.md."
	@echo "To reset test files, delete and re-create them or use a script."

```

**Explanation of Makefile:**

*   `CC`: Compiler (gcc).
*   `CFLAGS`: Compiler flags (`-Wall -Wextra` for more warnings, `-std=c11` for C11 standard, `-g` for debug symbols).
*   `TARGET_EXEC`: Name of the output executable.
*   `SRC_DIR`, `BUILD_DIR`: Source and build directories.
*   `SOURCES`, `OBJECTS`: Source files and corresponding object files.
*   `all`: Default target, builds the executable.
*   Rule for executable: Links object files.
*   Rule for object files: Compiles C source files into object files. `mkdir -p $(@D)` ensures the build subdirectory (e.g., `build/`) exists before trying to write an object file there.
*   `clean`: Removes the `build` directory.
*   `test`: A simple target to run the program with predefined arguments (useful for quick checks).

**Step 4: Build and Run**

1.  **Build the program:**
    Open your terminal in the `file_appender_c` directory and run:
    ```bash
    make
    ```
    This will compile `src/main.c` and create an executable `build/file_appender`.

2.  **Run the program:**
    ```bash
    ./build/file_appender ./test_dir "^Oxide.*" ./data.md
    ```
    *   `./build/file_appender`: The compiled program.
    *   `./test_dir`: The directory to scan.
    *   `"^Oxide.*"`: The POSIX ERE regex pattern.
        *   `^`: Matches the beginning of the filename.
        *   `Oxide`: Matches the literal string "Oxide".
        *   `.*`: Matches any character (`.`) zero or more times (`*`).
    *   `./data.md`: The file whose content will be appended.

    **Expected Output:**
    ```
    Searching in directory: ./test_dir
    Successfully read XX bytes from: ./data.md  (XX will be the size of your data.md)
    Using regex pattern: ^Oxide.*
    Found matching file: ./test_dir/OxideFile1.txt
    Successfully appended to ./test_dir/OxideFile1.txt
    Found matching file: ./test_dir/OxideLog2.doc
    Successfully appended to ./test_dir/OxideLog2.doc
    Found matching file: ./test_dir/subdir/OxideData3.md
    Successfully appended to ./test_dir/subdir/OxideData3.md

    Finished processing. Appended data to 3 file(s).
    ```

3.  **Verify the changes:**
    Check the contents of `test_dir/OxideFile1.txt`, `test_dir/OxideLog2.doc`, and `test_dir/subdir/OxideData3.md`. They should now have the content from `data.md` appended to them. `test_dir/NonOxideFile.txt` should remain unchanged.

    For example, `test_dir/OxideFile1.txt` would look like:
    ```
    Initial content for OxideFile1.
    --- Appended Content ---
    Timestamp: <current date and time>
    Source: C_CLI_Appender
    ------------------------
    ```

**Step 5: Testing**

The `Makefile` includes a basic `test` target:

```bash
make test
```

This target will:
1.  Ensure the project is built (`all` dependency).
2.  Show the initial content of `test_dir/OxideFile1.txt`.
3.  Run your `file_appender` program with the test parameters.
4.  Show the content of `test_dir/OxideFile1.txt` *after* the run.
5.  Show the content of `test_dir/NonOxideFile.txt` (which should be unchanged).

**For more robust testing, you would typically use a shell script or a C testing framework.** Here's an example of a simple shell script for testing:

Create `test_runner.sh` in the `file_appender_c` directory:

```bash
#!/bin/bash

# test_runner.sh

# Ensure script exits on error
set -e

BASE_DIR=$(pwd)
TEST_DIR_NAME="test_dir_automated"
TEST_DIR_PATH="$BASE_DIR/$TEST_DIR_NAME"
DATA_FILE_NAME="test_data.md"
DATA_FILE_PATH="$BASE_DIR/$DATA_FILE_NAME"
EXECUTABLE="./build/file_appender" # Assuming 'make' puts it here

# Function to set up test environment
setup_test_env() {
    echo "Setting up test environment..."
    rm -rf "$TEST_DIR_PATH" # Clean previous test run
    mkdir -p "$TEST_DIR_PATH/subdir"

    # Create data.md
    echo "--- Automated Test Append ---" > "$DATA_FILE_PATH"
    echo "Test Line 2" >> "$DATA_FILE_PATH"

    # Create test files
    echo "Initial Oxide Alpha" > "$TEST_DIR_PATH/OxideFileAlpha.txt"
    echo "Initial Oxide Beta" > "$TEST_DIR_PATH/subdir/OxideFileBeta.log"
    echo "Initial NonMatching Gamma" > "$TEST_DIR_PATH/NonMatchingFileGamma.md"
    echo "Empty Oxide Charlie" > "$TEST_DIR_PATH/OxideEmptyFileCharlie.dat"
}

# Function to clean up
cleanup() {
    echo "Cleaning up test environment..."
    rm -rf "$TEST_DIR_PATH"
    rm -f "$DATA_FILE_PATH"
}

# --- Run Tests ---

# 1. Build the program
echo "Building program..."
make clean # Clean previous build
make
if [ ! -f "$EXECUTABLE" ]; then
    echo "Build failed. Exiting."
    exit 1
fi

# 2. Setup
setup_test_env

# 3. Execute the program
echo "Running file_appender..."
"$EXECUTABLE" "$TEST_DIR_PATH" "^Oxide.*" "$DATA_FILE_PATH"

# 4. Verifications
echo "Verifying results..."
passed_tests=0
failed_tests=0

# Check OxideFileAlpha.txt
if grep -q "--- Automated Test Append ---" "$TEST_DIR_PATH/OxideFileAlpha.txt" && \
   grep -q "Initial Oxide Alpha" "$TEST_DIR_PATH/OxideFileAlpha.txt"; then
    echo "PASS: OxideFileAlpha.txt modified correctly."
    passed_tests=$((passed_tests + 1))
else
    echo "FAIL: OxideFileAlpha.txt not modified correctly or content missing."
    cat "$TEST_DIR_PATH/OxideFileAlpha.txt"
    failed_tests=$((failed_tests + 1))
fi

# Check subdir/OxideFileBeta.log
if grep -q "--- Automated Test Append ---" "$TEST_DIR_PATH/subdir/OxideFileBeta.log" && \
   grep -q "Initial Oxide Beta" "$TEST_DIR_PATH/subdir/OxideFileBeta.log"; then
    echo "PASS: subdir/OxideFileBeta.log modified correctly."
    passed_tests=$((passed_tests + 1))
else
    echo "FAIL: subdir/OxideFileBeta.log not modified correctly or content missing."
    cat "$TEST_DIR_PATH/subdir/OxideFileBeta.log"
    failed_tests=$((failed_tests + 1))
fi

# Check OxideEmptyFileCharlie.dat (should have only appended content)
if grep -q "--- Automated Test Append ---" "$TEST_DIR_PATH/OxideEmptyFileCharlie.dat" && \
   [ $(grep -cv "--- Automated Test Append ---" "$TEST_DIR_PATH/OxideEmptyFileCharlie.dat" | wc -l) -eq 1 ]; then # Check it doesn't contain initial lines
    echo "PASS: OxideEmptyFileCharlie.dat modified correctly."
    passed_tests=$((passed_tests + 1))
else
    echo "FAIL: OxideEmptyFileCharlie.dat not modified correctly or contains unexpected content."
    cat "$TEST_DIR_PATH/OxideEmptyFileCharlie.dat"
    failed_tests=$((failed_tests + 1))
fi


# Check NonMatchingFileGamma.md (should be unchanged)
if grep -q "Initial NonMatching Gamma" "$TEST_DIR_PATH/NonMatchingFileGamma.md" && \
   ! grep -q "--- Automated Test Append ---" "$TEST_DIR_PATH/NonMatchingFileGamma.md"; then
    echo "PASS: NonMatchingFileGamma.md was not modified."
    passed_tests=$((passed_tests + 1))
else
    echo "FAIL: NonMatchingFileGamma.md was modified or initial content lost."
    cat "$TEST_DIR_PATH/NonMatchingFileGamma.md"
    failed_tests=$((failed_tests + 1))
fi

echo "-----------------------------------"
echo "Test Summary: $passed_tests Passed, $failed_tests Failed."
echo "-----------------------------------"

# 5. Cleanup
# cleanup # Uncomment to automatically clean up after test

if [ $failed_tests -gt 0 ]; then
    exit 1
fi
exit 0
```

Make it executable and run:
```bash
chmod +x test_runner.sh
./test_runner.sh
```

This script sets up a clean test environment, runs your program, and then uses `grep` to check if files were modified as expected.

**Resources and Links:**

*   **Directory Traversal:**
    *   `dirent.h`: `man 3 opendir`, `man 3 readdir`, `man 3 closedir`
*   **File Status:**
    *   `sys/stat.h`: `man 2 stat`
*   **POSIX Regular Expressions:**
    *   `regex.h`: `man 3 regex` or `man 7 regex`
    *   Online regex tester (for POSIX ERE): Many available, e.g., regex101.com (select PCRE/ECMAScript and adapt slightly, or find a POSIX ERE specific one).
*   **File I/O:**
    *   `stdio.h`: `man 3 fopen`, `man 3 fread`, `man 3 fwrite`, `man 3 fclose`, `man 3 fseek`, `man 3 ftell`
*   **GNU Make Manual:** [https://www.gnu.org/software/make/manual/](https://www.gnu.org/software/make/manual/)
*   **GCC Compiler Options:** `man gcc`

This C solution provides a functional command-line tool for your specified task, along with build instructions and a testing approach. Remember that C requires careful memory management and error checking.
