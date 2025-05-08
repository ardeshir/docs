Okay, let's round out this comparison with C and modern C++. We'll follow the same structure and example scenarios.

---

**C Programming Overview**

**Philosophical Starting Points:**

*   **C:** A foundational, imperative programming language developed in the early 1970s. It's known for its efficiency, low-level memory access (pointers), and minimalistic runtime. C gives the programmer a high degree of control but also a high degree of responsibility, especially regarding memory management. It has been influential in the development of many other languages and remains critical for operating systems, embedded systems, and performance-critical applications. Standards like C99, C11, C17, and the upcoming C23 have added features while maintaining backward compatibility.

---

**Modern C++ Programming Overview (C++17/20/23)**

**Philosophical Starting Points:**

*   **C++:** An extension of C, C++ adds object-oriented features, generic programming (templates), and a rich standard library (STL). Modern C++ (C++11 and later, especially C++17, C++20, and C++23) has significantly evolved, emphasizing safer practices (RAII, smart pointers), more expressive syntax (lambdas, range-based for loops), compile-time computation (`constexpr`), and better concurrency support. It aims to provide high performance with high-level abstractions, making it suitable for game development, high-performance computing, operating systems, financial applications, and much more.

---

**Installation and Setup on Ubuntu Linux (C & C++)**

C and C++ compilers (like GCC/G++ which are part of the GNU Compiler Collection) and build tools are typically installed via the `build-essential` package on Debian/Ubuntu-based systems. `cmake` is a popular cross-platform build system generator.

1.  **Install Compilers and Build Tools:**
    ```bash
    sudo apt update
    sudo apt install -y build-essential cmake
    ```
    This command installs:
    *   `gcc`: The GNU C compiler.
    *   `g++`: The GNU C++ compiler.
    *   `make`: The GNU Make utility for building with Makefiles.
    *   Other essential development libraries and headers.
    *   `cmake`: The CMake build system generator.

2.  **Verify Installation:**
    ```bash
    gcc --version
    g++ --version
    make --version
    cmake --version
    ```
    You should see the versions of the installed tools.

**Compiling and Running C/C++ Code**

*   **Direct Compilation (Simple Cases):**
    *   For C: `gcc my_program.c -o my_program && ./my_program`
    *   For C++: `g++ my_program.cpp -o my_program -std=c++17 && ./my_program` (specify C++ standard)
*   **Using Makefiles:** (More structured for projects)
    *   Create a `Makefile`.
    *   Run `make` to build.
    *   Run `./my_program_executable_name`
*   **Using CMake:** (Preferred for larger/cross-platform C++ projects)
    *   Create a `CMakeLists.txt` file.
    *   Run `cmake .` (or `cmake -S . -B build` for out-of-source builds).
    *   Run `make` (inside the build directory if out-of-source).
    *   Run `./my_program_executable_name`

**"Packages" in C/C++:**
Unlike Go modules or NuGet, C/C++ doesn't have a centralized official package manager in the language itself. Dependencies are typically managed by:
1.  **System Package Managers:** `apt`, `yum`, `brew` (installing libraries like `libssl-dev`, `libboost-all-dev`).
2.  **Build System Features:** CMake's `find_package()` can locate installed libraries.
3.  **Vendorized Dependencies:** Including source code or pre-built libraries directly in the project.
4.  **External Package Managers:** Tools like Conan, vcpkg, Hunter.

For linking against common libraries (e.g., math library):
`gcc my_program.c -o my_program -lm` (links `libm.so`)

---

**Feature by Feature Comparison (C & C++)**

**1. Basic "Hello, World!" & Program Structure**

*   **C (`hello_c/hello.c`)**
    ```c
    #include <stdio.h> // Standard Input/Output library

    // main function is the entry point
    int main() {
        printf("Hello, C!\n");
        return 0; // Indicate successful execution
    }
    ```
    *Makefile (`hello_c/Makefile`):*
    ```makefile
    CC = gcc
    CFLAGS = -Wall -Wextra -std=c11 # C11 standard, enable warnings
    TARGET = hello_c_app

    all: $(TARGET)

    $(TARGET): hello.c
    	$(CC) $(CFLAGS) hello.c -o $(TARGET)

    clean:
    	rm -f $(TARGET)
    ```
    *Building and Running C:*
    ```bash
    cd hello_c
    make
    ./hello_c_app
    ```
    *Output:*
    ```
    Hello, C!
    ```

*   **C++ (`hello_cpp/hello.cpp`)**
    ```cpp
    #include <iostream> // Input/Output Stream library

    // main function is the entry point
    int main() {
        std::cout << "Hello, C++!" << std::endl;
        return 0; // Indicate successful execution
    }
    ```
    *Makefile (`hello_cpp/Makefile`):*
    ```makefile
    CXX = g++
    CXXFLAGS = -Wall -Wextra -std=c++17 # C++17 standard, enable warnings
    TARGET = hello_cpp_app

    all: $(TARGET)

    $(TARGET): hello.cpp
    	$(CXX) $(CXXFLAGS) hello.cpp -o $(TARGET)

    clean:
    	rm -f $(TARGET)
    ```
    *Building and Running C++ with Make:*
    ```bash
    cd hello_cpp
    make
    ./hello_cpp_app
    ```
    *Output:*
    ```
    Hello, C++!
    ```
    *CMake (`hello_cpp_cmake/CMakeLists.txt` and `hello_cpp_cmake/hello.cpp` - same cpp content):*
    ```cmake
    # CMakeLists.txt
    cmake_minimum_required(VERSION 3.10)
    project(HelloCppApp LANGUAGES CXX)

    set(CMAKE_CXX_STANDARD 17)
    set(CMAKE_CXX_STANDARD_REQUIRED True)
    set(CMAKE_CXX_EXTENSIONS OFF) # Use standard features, not GNU extensions

    add_executable(hello_cpp_cmake_app hello.cpp)

    # Optional: Add compiler warnings
    if(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_CLANG)
      target_compile_options(hello_cpp_cmake_app PRIVATE -Wall -Wextra)
    endif()
    ```
    *Building and Running C++ with CMake:*
    ```bash
    # Assuming hello.cpp is in hello_cpp_cmake directory
    cd hello_cpp_cmake
    cmake -S . -B build # Configure, create build directory
    cmake --build build  # Build the project (invokes make internally)
    ./build/hello_cpp_cmake_app
    ```

**2. Error Handling (Reading a file that might not exist)**

*   **C (`read_file_c/read_file.c`)**
    ```c
    #include <stdio.h>
    #include <stdlib.h> // For malloc, free, exit
    #include <errno.h>  // For errno
    #include <string.h> // For strerror

    // Reads entire file content into a dynamically allocated string.
    // Caller must free the returned string.
    char* read_file_content(const char* path, long* out_size) {
        FILE *file = fopen(path, "rb"); // Open in binary read mode
        if (file == NULL) {
            // perror("Error opening file (C)"); // perror prints to stderr
            return NULL; // Indicate error by returning NULL
        }

        fseek(file, 0, SEEK_END); // Go to end of file
        long size = ftell(file);  // Get current file pointer position (size)
        if (size == -1) {
            fclose(file);
            return NULL;
        }
        fseek(file, 0, SEEK_SET); // Go back to beginning of file

        char *content = (char*)malloc(size + 1); // +1 for null terminator
        if (content == NULL) {
            fclose(file);
            // fprintf(stderr, "Memory allocation failed (C)\n");
            return NULL;
        }

        size_t bytes_read = fread(content, 1, size, file);
        if (bytes_read != (size_t)size) { // Cast size to size_t for comparison
            if (ferror(file)) {
                // An actual read error occurred
                // fprintf(stderr, "Error reading file (C): %s\n", strerror(errno));
            } else if (feof(file)) {
                // Reached end-of-file unexpectedly (e.g., file shrunk)
                // fprintf(stderr, "EOF reached prematurely (C)\n");
            }
            free(content);
            fclose(file);
            return NULL;
        }
        content[size] = '\0'; // Null-terminate the string

        if (out_size != NULL) {
            *out_size = size;
        }

        fclose(file);
        return content;
    }

    int main() {
        const char* file_path = "example.txt";
        // Create a dummy file: FILE* f = fopen(file_path, "w"); if(f) { fprintf(f, "Content from C!"); fclose(f); }

        long file_size;
        char *content = read_file_content(file_path, &file_size);

        if (content == NULL) {
            // Check errno for fopen failure specifics, or ferror for fread issues
            fprintf(stderr, "Error reading file (C): %s (errno: %d)\n", strerror(errno), errno);
            if (errno == ENOENT) {
                fprintf(stderr, "The file was not found.\n");
            }
            return 1; // Indicate error
        }

        printf("File content (C) (%ld bytes):\n%s\n", file_size, content);
        free(content); // IMPORTANT: Free allocated memory

        return 0;
    }
    ```
    *Makefile (`read_file_c/Makefile`):*
    ```makefile
    CC = gcc
    CFLAGS = -Wall -Wextra -std=c11
    TARGET = read_file_c_app

    all: $(TARGET)
    $(TARGET): read_file.c
    	$(CC) $(CFLAGS) read_file.c -o $(TARGET)
    clean:
    	rm -f $(TARGET)
    ```
    *Build & Run:*
    ```bash
    cd read_file_c
    # To test success: echo "Content from C!" > example.txt
    make && ./read_file_c_app
    # To test error: rm example.txt; make && ./read_file_c_app
    ```

*   **C++ (`read_file_cpp/read_file.cpp`)**
    ```cpp
    #include <iostream>
    #include <fstream>   // For file streams
    #include <string>    // For std::string
    #include <sstream>   // For std::stringstream
    #include <system_error> // For std::error_code
    #include <cerrno>    // For specific errno values like ENOENT

    // Option 1: Using exceptions (idiomatic C++ for many stream errors)
    std::string read_file_content_exceptions(const std::string& path) {
        std::ifstream file(path, std::ios::binary); // Open in binary mode
        if (!file.is_open()) {
            // Could throw a custom exception or std::ios_base::failure
            throw std::ios_base::failure("Error opening file (C++): " + path + " - " + strerror(errno));
        }

        // Read the whole file into a stringstream
        std::stringstream buffer;
        buffer << file.rdbuf(); // rdbuf() gets a pointer to the stream buffer

        if (file.bad()) { // Check for non-recoverable stream errors
             throw std::ios_base::failure("Error reading file (C++): " + path + " - " + strerror(errno));
        }
        // file.fail() could also be checked for formatting errors if not reading raw bytes

        return buffer.str();
    }

    // Option 2: Using std::error_code (for non-exceptional error paths)
    std::string read_file_content_error_code(const std::string& path, std::error_code& ec) {
        ec.clear(); // Clear any previous error state
        std::ifstream file(path, std::ios::binary);
        if (!file.is_open()) {
            // Construct error_code from errno
            ec = std::error_code(errno, std::system_category());
            return "";
        }

        std::stringstream buffer;
        buffer << file.rdbuf();

        if (file.bad()) {
            ec = std::error_code(errno, std::system_category());
            return "";
        }
        // file.fail() can also set an error, but rdbuf usually handles that or sets badbit.
        // If specifically checking after the read and not during:
        // if (file.fail() && !file.eof()){ // fail but not because of eof
        //    ec = std::make_error_code(std::errc::io_error); // generic io_error
        //    return "";
        // }

        return buffer.str();
    }


    int main() {
        const std::string file_path = "example.txt";
        // Create dummy file: std::ofstream outfile(file_path); outfile << "Content from C++!"; outfile.close();

        std::cout << "--- Using exceptions ---" << std::endl;
        try {
            std::string content = read_file_content_exceptions(file_path);
            std::cout << "File content (C++ exceptions):\n" << content << std::endl;
        } catch (const std::ios_base::failure& e) {
            std::cerr << "Exception caught (C++): " << e.what() << std::endl;
            // To check for specific errors like file not found, you might need to parse e.what()
            // or have the throwing function provide more structured error info.
            // Or check errno right after the open failed inside the function if it's a concern.
            // std::system_error often carries an error_code.
            if (dynamic_cast<const std::system_error*>(&e)) {
                const auto& sys_err = static_cast<const std::system_error&>(e);
                if (sys_err.code().value() == ENOENT) {
                     std::cerr << "The file was not found (checked via system_error from exception)." << std::endl;
                }
            } else if (strstr(e.what(), "No such file or directory")) { // Less robust check
                std::cerr << "The file was not found (checked via string in exception)." << std::endl;
            }
        } catch (const std::exception& e) {
            std::cerr << "Generic exception caught (C++): " << e.what() << std::endl;
        }


        std::cout << "\n--- Using std::error_code ---" << std::endl;
        std::error_code ec;
        std::string content_ec = read_file_content_error_code(file_path, ec);
        if (ec) {
            std::cerr << "Error reading file (C++ error_code): " << ec.message()
                      << " (value: " << ec.value() << ")" << std::endl;
            if (ec.value() == ENOENT || ec == std::errc::no_such_file_or_directory) { // std::errc provides portable codes
                std::cerr << "The file was not found." << std::endl;
            }
        } else {
            std::cout << "File content (C++ error_code):\n" << content_ec << std::endl;
        }

        return 0;
    }
    ```
    *Makefile (`read_file_cpp/Makefile`):*
    ```makefile
    CXX = g++
    CXXFLAGS = -Wall -Wextra -std=c++17
    TARGET = read_file_cpp_app

    all: $(TARGET)
    $(TARGET): read_file.cpp
    	$(CXX) $(CXXFLAGS) read_file.cpp -o $(TARGET)
    clean:
    	rm -f $(TARGET)
    ```
    *Build & Run:*
    ```bash
    cd read_file_cpp
    # To test success: echo "Content from C++!" > example.txt
    make && ./read_file_cpp_app
    # To test error: rm example.txt; make && ./read_file_cpp_app
    ```

    *Key Differences (C vs C++ Error Handling):*
    *   **C:** Relies on return codes (e.g., `NULL` from `fopen`), `errno` for system call error details, and functions like `perror` or `strerror` to interpret `errno`. `ferror` checks stream error flags.
    *   **C++:**
        *   Streams (`std::ifstream`) have state flags (`good()`, `fail()`, `bad()`, `eof()`) that can be checked.
        *   Exceptions (`std::ios_base::failure`, `std::system_error`) are common for I/O errors. `try-catch` blocks handle them.
        *   `std::error_code` (from `<system_error>`) offers a non-exceptional way to report errors, often used with `std::filesystem` or when exceptions are undesirable.

**3. Generics / Compile-Time Polymorphism (Generic Add Function)**

*   **C (`generics_c/generics.c`)**
    C doesn't have true generics like C++ templates. Options:
    1.  Macros (type-unsafe or complex to make safe).
    2.  `void*` (type erasure, runtime checks/casts needed).
    3.  C11 `_Generic` for type-dispatching.

    ```c
    #include <stdio.h>

    // 1. Using Macros (simple but less type-safe for more complex ops)
    #define DEFINE_ADD_AND_PRINT_FN(SUFFIX, TYPE, FORMAT_SPECIFIER) \
        void add_and_print_##SUFFIX(TYPE a, TYPE b) { \
            TYPE result = a + b; \
            printf(#SUFFIX ": %" #FORMAT_SPECIFIER " + %" #FORMAT_SPECIFIER " = %" #FORMAT_SPECIFIER "\n", a, b, result); \
        }

    DEFINE_ADD_AND_PRINT_FN(int, int, d)
    DEFINE_ADD_AND_PRINT_FN(double, double, f)
    // Note: String concatenation with '+' doesn't work in C like this.

    // 2. Using C11 _Generic for type dispatch (for a single expression)
    // This is for the `add` part, print would be separate or more complex.
    #define add(a, b) _Generic((a), \
        int: ((int)(a) + (int)(b)), \
        double: ((double)(a) + (double)(b)), \
        default: 0 /* Or some error handling */ \
    )

    // More complete _Generic example for print combined
    #define ADD_AND_PRINT_GENERIC(A, B) \
        _Generic((A), \
            int: printf("Generic int: %d + %d = %d\n", (int)(A), (int)(B), (int)(A) + (int)(B)), \
            double: printf("Generic double: %f + %f = %f\n", (double)(A), (double)(B), (double)(A) + (double)(B)), \
            char*: printf("Generic char*: (concat not with +) %s, %s\n", (char*)(A), (char*)(B)) \
        )


    int main() {
        printf("--- Using specific functions generated by macros ---\n");
        add_and_print_int(5, 10);
        add_and_print_double(3.14, 2.71);

        printf("\n--- Using _Generic macro for addition result ---\n");
        int sum_int = add(5, 10);
        double sum_double = add(3.14, 2.71);
        printf("_Generic sum_int: %d\n", sum_int);
        printf("_Generic sum_double: %f\n", sum_double);

        printf("\n--- Using _Generic macro for combined add and print ---\n");
        ADD_AND_PRINT_GENERIC(5, 10);
        ADD_AND_PRINT_GENERIC(3.14, 2.71);
        // ADD_AND_PRINT_GENERIC("Hello, ", "C _Generic!"); // String concat is different

        // C string concatenation:
        char str_buf[50];
        char *s1 = "Hello, ";
        char *s2 = "C strings!";
        sprintf(str_buf, "%s%s", s1, s2); // Or strcpy/strcat with care
        printf("C string concat: %s\n", str_buf);

        return 0;
    }
    ```
    *Makefile (`generics_c/Makefile`):*
    ```makefile
    CC = gcc
    CFLAGS = -Wall -Wextra -std=c11 # C11 for _Generic
    TARGET = generics_c_app

    all: $(TARGET)
    $(TARGET): generics.c
    	$(CC) $(CFLAGS) generics.c -o $(TARGET)
    clean:
    	rm -f $(TARGET)
    ```

*   **C++ (`generics_cpp/generics.cpp`)**
    C++ uses templates. C++20 adds concepts for constraining templates.
    ```cpp
    #include <iostream>
    #include <string>
    #include <type_traits> // For std::is_arithmetic, std::enable_if_t
    #include <concepts>    // For C++20 concepts

    // C++17 way with SFINAE or static_assert
    template <typename T>
    // std::enable_if_t<std::is_arithmetic_v<T>> // SFINAE to restrict to arithmetic types
    void addAndPrintOld(T a, T b) {
        // static_assert(std::is_arithmetic_v<T>, "addAndPrintOld requires arithmetic types.");
        // For string, '+' is overloaded for std::string.
        // If we strictly want numeric, the static_assert or enable_if is good.
        auto result = a + b;
        std::cout << a << " + " << b << " = " << result << std::endl;
    }


    // C++20 way with concepts
    // Define a concept for types that support addition and can be streamed to cout
    template <typename T>
    concept AddableAndPrintable = requires(T a, T b) {
        { a + b } -> std::convertible_to<T>; // Check if a + b is valid and result is convertible to T
        { std::cout << a };                 // Check if T can be streamed to cout
    };
    // Or a simpler concept just for addition:
    // template<typename T>
    // concept Addable = requires(T a, T b) { a + b; };


    template <AddableAndPrintable T> // Use the concept
    void addAndPrint(T a, T b) {
        auto result = a + b;
        std::cout << a << " + " << b << " = " << result << std::endl;
    }

    // Overload for C-style strings (char*) to demonstrate specific handling if needed,
    // though std::string would be preferred and covered by the template.
    void addAndPrint(const char* a, const char* b) {
        std::string s_a = a;
        std::string s_b = b;
        std::cout << s_a << " + " << s_b << " = " << (s_a + s_b) << " (as std::strings)" << std::endl;
    }


    int main() {
        std::cout << "--- C++17 style (or earlier) ---" << std::endl;
        addAndPrintOld(5, 10);
        addAndPrintOld(3.14, 2.71);
        addAndPrintOld(std::string("Hello, "), std::string("C++ old style!"));

        std::cout << "\n--- C++20 style with concepts ---" << std::endl;
        addAndPrint(5, 10);       // int
        addAndPrint(3.14, 2.71);  // double
        addAndPrint(std::string("Hello, "), std::string("C++20 Concepts!"));
        // addAndPrint("Raw ", "strings"); // Calls the (const char*, const char*) overload

        // The following would fail to compile if AddableAndPrintable didn't account for operator<<
        // or if a + b wasn't defined:
        // struct NoAdd {};
        // addAndPrint(NoAdd{}, NoAdd{}); // Compiler error: constraints not satisfied
    }
    ```
    *Makefile (`generics_cpp/Makefile`):*
    ```makefile
    CXX = g++
    # Use C++20 for concepts. Fallback to C++17 for the "old" example if C++20 not default.
    CXXFLAGS = -Wall -Wextra -std=c++20
    TARGET = generics_cpp_app

    all: $(TARGET)
    $(TARGET): generics.cpp
    	$(CXX) $(CXXFLAGS) generics.cpp -o $(TARGET)
    clean:
    	rm -f $(TARGET)
    ```

    *Key Differences (C vs C++ Generics):*
    *   **C:** No direct support. Macros are error-prone and offer limited type safety. `_Generic` (C11+) provides type-based dispatch for expressions but is verbose for function-like generics. `void*` requires manual type management and casting.
    *   **C++:** Templates provide powerful, type-safe compile-time polymorphism. C++20 Concepts allow for explicit definition of template parameter requirements, improving error messages and design.

**4. Memory Management (Focus: Dynamic Arrays)**

*   **C (`memory_c/dyn_array.c`)**
    Manual memory management with `malloc`, `realloc`, `free`.
    ```c
    #include <stdio.h>
    #include <stdlib.h> // For malloc, realloc, free
    #include <string.h> // For memcpy

    typedef struct {
        int *data;
        size_t size;     // Number of elements currently stored
        size_t capacity; // Allocated memory capacity (in elements)
    } IntVector;

    void init_vector(IntVector *vec, size_t initial_capacity) {
        if (initial_capacity == 0) initial_capacity = 1; // Avoid zero allocation
        vec->data = (int*)malloc(initial_capacity * sizeof(int));
        if (vec->data == NULL) {
            perror("Failed to initialize vector");
            exit(EXIT_FAILURE);
        }
        vec->size = 0;
        vec->capacity = initial_capacity;
    }

    void push_back(IntVector *vec, int value) {
        if (vec->size == vec->capacity) {
            // Resize: double the capacity
            size_t new_capacity = vec->capacity * 2;
            int *new_data = (int*)realloc(vec->data, new_capacity * sizeof(int));
            if (new_data == NULL) {
                perror("Failed to resize vector");
                // Original vec->data is still valid if realloc fails, but we can't add.
                // For simplicity, exiting. A real app might try smaller resize or propagate error.
                exit(EXIT_FAILURE);
            }
            vec->data = new_data;
            vec->capacity = new_capacity;
        }
        vec->data[vec->size++] = value;
    }

    int pop_back(IntVector *vec) {
        if (vec->size == 0) {
            fprintf(stderr, "Cannot pop from empty vector\n");
            exit(EXIT_FAILURE); // Or return an error code/sentinel
        }
        return vec->data[--vec->size]; // Return value and decrease size
    }

    void free_vector(IntVector *vec) {
        free(vec->data);
        vec->data = NULL;
        vec->size = 0;
        vec->capacity = 0;
    }

    void print_vector(const IntVector *vec) {
        printf("Vector (C) - Size: %zu, Capacity: %zu, Data: [", vec->size, vec->capacity);
        for (size_t i = 0; i < vec->size; ++i) {
            printf("%d%s", vec->data[i], (i == vec->size - 1) ? "" : ", ");
        }
        printf("]\n");
    }

    int main() {
        IntVector numbers;
        init_vector(&numbers, 2); // Initial capacity of 2

        print_vector(&numbers);

        push_back(&numbers, 10);
        print_vector(&numbers);
        push_back(&numbers, 20);
        print_vector(&numbers);
        push_back(&numbers, 30); // Should trigger realloc
        print_vector(&numbers);

        int val = pop_back(&numbers);
        printf("Popped: %d\n", val);
        print_vector(&numbers);

        free_vector(&numbers); // Crucial to avoid memory leaks
        return 0;
    }
    ```
    *Makefile (`memory_c/Makefile`):*
    ```makefile
    CC = gcc
    CFLAGS = -Wall -Wextra -std=c11
    TARGET = memory_c_app

    all: $(TARGET)
    $(TARGET): dyn_array.c
    	$(CC) $(CFLAGS) dyn_array.c -o $(TARGET)
    clean:
    	rm -f $(TARGET)
    ```

*   **C++ (`memory_cpp/std_vector.cpp`)**
    `std::vector` handles memory automatically (RAII).
    ```cpp
    #include <iostream>
    #include <vector>    // For std::vector
    #include <string>    // For joining (not directly used for print here)

    template<typename T>
    void print_vector_info(const std::vector<T>& vec, const std::string& name = "Vector") {
        std::cout << name << " (C++) - Size: " << vec.size()
                  << ", Capacity: " << vec.capacity() << ", Data: [";
        for (size_t i = 0; i < vec.size(); ++i) {
            std::cout << vec[i] << (i == vec.size() - 1 ? "" : ", ");
        }
        std::cout << "]" << std::endl;
    }

    int main() {
        std::vector<int> numbers; // Initially empty, default capacity (often 0)
        // numbers.reserve(2); // Can pre-allocate if desired

        print_vector_info(numbers, "Initial numbers");

        numbers.push_back(10);
        print_vector_info(numbers, "After push_back(10)");
        numbers.push_back(20);
        print_vector_info(numbers, "After push_back(20)");
        numbers.push_back(30); // May trigger reallocation
        print_vector_info(numbers, "After push_back(30)");

        if (!numbers.empty()) {
            int val = numbers.back(); // Get last element
            numbers.pop_back();     // Remove last element
            std::cout << "Popped: " << val << std::endl;
            print_vector_info(numbers, "After pop_back");
        }

        // Memory is automatically managed by std::vector's destructor when `numbers`
        // goes out of scope (RAII - Resource Acquisition Is Initialization).
        // No explicit free/delete needed for the vector's internal buffer.

        return 0;
    }
    ```
    *Makefile (`memory_cpp/Makefile`):*
    ```makefile
    CXX = g++
    CXXFLAGS = -Wall -Wextra -std=c++17
    TARGET = memory_cpp_app

    all: $(TARGET)
    $(TARGET): std_vector.cpp
    	$(CXX) $(CXXFLAGS) std_vector.cpp -o $(TARGET)
    clean:
    	rm -f $(TARGET)
    ```

    *Key Differences (C vs C++ Dynamic Arrays):*
    *   **C:** Fully manual. Requires `malloc`/`realloc`/`free`. Programmer must track size and capacity, handle allocation failures, and ensure memory is freed to prevent leaks. Easy to make mistakes.
    *   **C++:** `std::vector` provides an abstraction that handles memory automatically using RAII. It manages its own capacity, reallocates when needed, and its destructor frees the memory. Much safer and easier to use.

**5. Metaprogramming**

*   **C (`metaprog_c/macros.c`)**
    Primarily via the C Preprocessor (macros).
    ```c
    #include <stdio.h>

    // 1. Simple constant definition
    #define PI 3.14159

    // 2. Function-like macro
    #define SQUARE(x) ((x) * (x)) // Parentheses are important!

    // 3. Stringification (#) and Token Pasting (##)
    #define PRINT_VAR(var) printf(#var " = %d\n", var)
    #define DECLARE_NAMED_INT(name_part) int integer_##name_part

    // 4. Conditional compilation
    #define DEBUG_MODE 1 // Try 0 or undefine

    // 5. Generating code (e.g., for enums and string conversion)
    #define FOREACH_FRUIT(FRUIT_MACRO) \
        FRUIT_MACRO(APPLE, 0)   \
        FRUIT_MACRO(BANANA, 1)  \
        FRUIT_MACRO(ORANGE, 2)

    #define GENERATE_ENUM(name, val) name = val,
    #define GENERATE_STRING_CASE(name, val) case name: return #name;

    typedef enum {
        FOREACH_FRUIT(GENERATE_ENUM)
        FRUIT_COUNT
    } Fruit;

    const char* fruit_to_string(Fruit f) {
        switch (f) {
            FOREACH_FRUIT(GENERATE_STRING_CASE)
            default: return "Unknown Fruit";
        }
    }

    int main() {
        printf("PI = %f\n", PI);
        printf("SQUARE(5) = %d\n", SQUARE(5));
        printf("SQUARE(2.5 + 1.5) = %f\n", SQUARE(2.5 + 1.5)); // (2.5+1.5)*(2.5+1.5)

        int my_value = 100;
        PRINT_VAR(my_value);

        DECLARE_NAMED_INT(one) = 1; // Declares int integer_one = 1;
        DECLARE_NAMED_INT(two) = 2;
        printf("integer_one = %d, integer_two = %d\n", integer_one, integer_two);

        #if DEBUG_MODE == 1
            printf("Debug mode is ON.\n");
        #else
            printf("Debug mode is OFF.\n");
        #endif

        printf("\nFruits:\n");
        for (int i = 0; i < FRUIT_COUNT; ++i) {
            printf("%s (%d)\n", fruit_to_string((Fruit)i), i);
        }
        return 0;
    }
    ```
    *Makefile (`metaprog_c/Makefile`):*
    ```makefile
    CC = gcc
    CFLAGS = -Wall -Wextra -std=c11
    TARGET = metaprog_c_app

    all: $(TARGET)
    $(TARGET): macros.c
    	$(CC) $(CFLAGS) macros.c -o $(TARGET)
    clean:
    	rm -f $(TARGET)
    ```

*   **C++ (`metaprog_cpp/templates_constexpr.cpp`)**
    Templates, `constexpr`, `if constexpr`, `consteval`, concepts.
    ```cpp
    #include <iostream>
    #include <string>
    #include <array> // For std::array
    #include <type_traits> // For std::is_integral_v

    // 1. Compile-time constants and functions (constexpr)
    constexpr double PI = 3.1415926535;

    constexpr long long factorial(int n) {
        return (n <= 1) ? 1 : (n * factorial(n - 1));
    }

    // 2. Template Metaprogramming (TMP) - e.g., compile-time factorial
    template <int N>
    struct Factorial {
        static_assert(N >= 0, "Factorial input must be non-negative");
        static constexpr long long value = N * Factorial<N - 1>::value;
    };
    template <> // Specialization for base case
    struct Factorial<0> {
        static constexpr long long value = 1;
    };

    // 3. `if constexpr` (C++17) for conditional compilation based on type traits
    template <typename T>
    auto get_value_string(T val) {
        if constexpr (std::is_pointer_v<T>) {
            if (val == nullptr) return std::string("nullptr");
            return std::to_string(*val); // Dereference pointer
        } else if constexpr (std::is_integral_v<T>) {
            return std::string("Integral: ") + std::to_string(val);
        } else if constexpr (std::is_floating_point_v<T>) {
            return std::string("Float: ") + std::to_string(val);
        } else {
            return std::string("Other type"); // Or static_assert(false, "Unsupported type");
        }
    }

    // 4. Generating code with templates: e.g., a lookup table
    template<typename Enum, Enum V>
    constexpr const char* enum_to_string_single() {
        // This requires specific implementations or more advanced TMP
        // For a simple demo, let's assume we have a mapping
        if constexpr (std::is_same_v<Enum, Fruit>){
            if constexpr (V == Fruit::APPLE) return "Apple";
            if constexpr (V == Fruit::BANANA) return "Banana";
            if constexpr (V == Fruit::ORANGE) return "Orange";
        }
        return "Unknown";
    }
    enum class Fruit { APPLE, BANANA, ORANGE };


    int main() {
        std::cout << "PI = " << PI << std::endl;
        constexpr long long fact5 = factorial(5); // Computed at compile time
        std::cout << "Factorial(5) (constexpr func) = " << fact5 << std::endl;

        std::cout << "Factorial<5>::value (TMP) = " << Factorial<5>::value << std::endl;
        // Factorial<-1>::value; // static_assert would fire

        int i = 10;
        double d = 3.3;
        int* p_i = &i;
        int* p_null = nullptr;

        std::cout << "get_value_string(i): " << get_value_string(i) << std::endl;
        std::cout << "get_value_string(d): " << get_value_string(d) << std::endl;
        std::cout << "get_value_string(p_i): " << get_value_string(p_i) << std::endl;
        std::cout << "get_value_string(p_null): " << get_value_string(p_null) << std::endl;

        std::cout << "Enum APPLE to string: " << enum_to_string_single<Fruit, Fruit::APPLE>() << std::endl;

        // C++ also has #define macros, but templates and constexpr are preferred for type safety and expressiveness.
        #define GREETING "Hello from C++ define!"
        std::cout << GREETING << std::endl;
        return 0;
    }
    ```
    *Makefile (`metaprog_cpp/Makefile`):*
    ```makefile
    CXX = g++
    CXXFLAGS = -Wall -Wextra -std=c++17 # Need C++17 for if constexpr
    TARGET = metaprog_cpp_app

    all: $(TARGET)
    $(TARGET): templates_constexpr.cpp
    	$(CXX) $(CXXFLAGS) templates_constexpr.cpp -o $(TARGET)
    clean:
    	rm -f $(TARGET)
    ```

    *Key Differences (C vs C++ Metaprogramming):*
    *   **C:** Limited to the preprocessor (textual substitution, token pasting, stringification, conditional compilation). Powerful but lacks type safety and can lead to obscure errors.
    *   **C++:**
        *   Retains C's preprocessor but its use is often discouraged in favor of C++ features.
        *   Templates enable Turing-complete compile-time computation (TMP).
        *   `constexpr` allows functions and variables to be evaluated at compile time.
        *   `if constexpr` (C++17) provides compile-time conditional branching within templates based on type properties.
        *   `consteval` (C++20) for immediate functions (must be evaluated at compile time).
        *   Source code generation can also be done via external tools, similar to `go generate`.

**6. C Interoperability**

Using the same C library (`my_c_lib.h`, `my_c_lib.c`) as in previous examples.
```bash
# In a directory with my_c_lib.c and my_c_lib.h
# Compile C library (e.g., into a shared object)
gcc -c -fPIC my_c_lib.c -o my_c_lib.o
gcc -shared -o libmy_c_lib.so my_c_lib.o
# For static: ar rcs libmy_c_lib.a my_c_lib.o
# Ensure libmy_c_lib.so is in a place linker can find.
```

*   **C (`c_interop_c/main.c`)**
    C interoperability *is* C. This example just shows calling functions from our "library".
    ```c
    #include <stdio.h>
    #include "my_c_lib.h" // Assuming my_c_lib.h is in the include path or same dir

    int main() {
        // Ensure libmy_c_lib.so is found by the dynamic linker (e.g. LD_LIBRARY_PATH)
        // or statically link my_c_lib.o / libmy_c_lib.a
        printf("Calling functions from my_c_lib (C from C)...\n");

        int sum = add_integers(5, 7);
        printf("Sum from C library: %d\n", sum);

        const char* message = "Hello from main C program to C library!";
        print_message(message);

        return 0;
    }
    ```
    *Makefile (`c_interop_c/Makefile`):*
    Assumes `my_c_lib.c` and `my_c_lib.h` are in a `../c_lib` directory relative to `c_interop_c`.
    ```makefile
    CC = gcc
    CFLAGS = -Wall -Wextra -std=c11 -I../c_lib # Add include path for my_c_lib.h
    LDFLAGS = -L../c_lib # Add library path for linker
    LDLIBS = -lmy_c_lib  # Link against libmy_c_lib.so or .a

    TARGET = c_interop_c_app

    # Build the C library first if it's source
    # This example assumes pre-built or builds it here for simplicity
    # If my_c_lib.c is available:
    # C_LIB_OBJ = ../c_lib/my_c_lib.o
    # C_LIB_SHARED = ../c_lib/libmy_c_lib.so

    # $(C_LIB_OBJ): ../c_lib/my_c_lib.c ../c_lib/my_c_lib.h
    #	$(CC) $(CFLAGS) -c ../c_lib/my_c_lib.c -o $(C_LIB_OBJ)

    # $(C_LIB_SHARED): $(C_LIB_OBJ)
    #	$(CC) -shared $(C_LIB_OBJ) -o $(C_LIB_SHARED)

    all: $(TARGET)

    # $(TARGET): main.c $(C_LIB_SHARED) # Depend on the shared library
    $(TARGET): main.c
    	$(CC) $(CFLAGS) main.c $(LDFLAGS) $(LDLIBS) -o $(TARGET)
    	# If linking against .o directly:
    	# $(CC) $(CFLAGS) main.c ../c_lib/my_c_lib.o -o $(TARGET)


    clean:
    	rm -f $(TARGET) # ../c_lib/my_c_lib.o ../c_lib/libmy_c_lib.so
    ```
    *To run (setup):*
    ```bash
    mkdir c_lib
    cp my_c_lib.c my_c_lib.h c_lib/
    cd c_lib && gcc -c -fPIC my_c_lib.c -o my_c_lib.o && gcc -shared -o libmy_c_lib.so my_c_lib.o && cd ..
    # Now build and run c_interop_c
    cd c_interop_c
    make
    # Ensure libmy_c_lib.so is findable:
    export LD_LIBRARY_PATH=$(pwd)/../c_lib:$LD_LIBRARY_PATH
    ./c_interop_c_app
    ```

*   **C++ (`c_interop_cpp/main.cpp`)**
    C++ uses `extern "C"` for linking with C code to handle name mangling.
    ```cpp
    #include <iostream>
    #include <string>

    // Tell the C++ compiler that these functions use C linkage (no name mangling)
    extern "C" {
        #include "my_c_lib.h" // Include the C header
    }

    int main() {
        // Ensure libmy_c_lib.so is found by the dynamic linker (e.g. LD_LIBRARY_PATH)
        std::cout << "Calling C functions from C++..." << std::endl;

        int sum = add_integers(5, 7); // Directly call the C function
        std::cout << "Sum from C library (via C++): " << sum << std::endl;

        const char* cpp_message = "Hello from C++ to C library!";
        print_message(cpp_message); // Call the C function

        return 0;
    }
    ```
    *Makefile (`c_interop_cpp/Makefile`):*
    Same `../c_lib` structure as for C.
    ```makefile
    CXX = g++
    CXXFLAGS = -Wall -Wextra -std=c++17 -I../c_lib
    LDFLAGS = -L../c_lib
    LDLIBS = -lmy_c_lib

    TARGET = c_interop_cpp_app

    all: $(TARGET)

    $(TARGET): main.cpp
    	$(CXX) $(CXXFLAGS) main.cpp $(LDFLAGS) $(LDLIBS) -o $(TARGET)

    clean:
    	rm -f $(TARGET)
    ```
    *To run (setup like for C, then):*
    ```bash
    # (ensure c_lib with libmy_c_lib.so is present in parent dir)
    cd c_interop_cpp
    make
    export LD_LIBRARY_PATH=$(pwd)/../c_lib:$LD_LIBRARY_PATH
    ./c_interop_cpp_app
    ```

    *Key Differences (C vs C++ C Interop):*
    *   **C:** Calling C code from C is just normal function calling. Linking involves standard C compiler/linker steps.
    *   **C++:** Must use `extern "C"` when declaring or including C functions to prevent C++ name mangling and ensure C linkage compatibility. Otherwise, calling C functions is straightforward.

---

**Summary of Unique Strengths (C & C++)**

*   **C's Unique Strengths:**
    *   **Portability & Ubiquity:** C compilers exist for nearly every platform. C code is highly portable.
    *   **Direct Memory Access & Control:** Unparalleled control over memory layout and hardware.
    *   **Simplicity & Small Footprint:** Minimalist language and runtime, ideal for embedded systems and OS kernels.
    *   **Performance:** Compiled C code is typically very fast and efficient.
    *   **Foundation:** Many OS APIs, libraries, and other languages are built with or expose C interfaces.

*   **Modern C++'s Unique Strengths:**
    *   **Multi-Paradigm:** Supports procedural, object-oriented, generic, and functional programming styles.
    *   **Performance with Abstraction (Zero-Cost Abstractions):** Aims to provide high-level abstractions (like `std::vector`, `std::string`, algorithms) without performance overhead compared to equivalent C code.
    *   **RAII & Smart Pointers:** Powerful idioms for resource management, greatly improving safety over manual C memory management (e.g., `std::unique_ptr`, `std::shared_ptr`).
    *   **Rich Standard Library (STL):** Comprehensive library for containers, algorithms, strings, I/O, threading, etc.
    *   **Template Metaprogramming & `constexpr`:** Extensive compile-time computation capabilities.
    *   **Expressiveness:** Modern features (lambdas, range-based for, structured bindings, concepts) make code more concise and readable.
    *   **Large Existing Codebase & Community:** Vast amounts of existing C++ code, libraries, and a large, active developer community.

---

**Conclusion (for C and C++)**

*   Choose **C** when:
    *   Working on embedded systems with severe resource constraints.
    *   Developing operating system kernels or low-level system utilities.
    *   Maximum portability across diverse and obscure platforms is essential.
    *   Interfacing directly with hardware where precise memory control is paramount.
    *   You need a language with a minimal runtime and ABI stability.

*   Choose **Modern C++** when:
    *   You need high performance comparable to C but want higher-level abstractions and better safety features.
    *   Building large-scale applications (games, desktop apps, high-performance servers, financial systems) where OOP, generics, and a rich STL are beneficial.
    *   Resource management with RAII is desired to prevent leaks and manage resources robustly.
    *   Leveraging advanced compile-time features for optimization or code generation.
    *   You are working with existing C++ codebases or need libraries primarily available for C++.

C remains the lingua franca for low-level programming. Modern C++ offers a path to manage complexity and improve safety while retaining most of C's performance characteristics, but it is a significantly larger and more complex language.

---

**Further Resources:**

*   **C:**
    *   "The C Programming Language" by Kernighan & Ritchie (K&R) - The classic, though covers older C.
    *   Modern C (Book by Jens Gustedt): [https://modernc.gforge.inria.fr/](https://modernc.gforge.inria.fr/)
    *   GCC Manual (for C): [https://gcc.gnu.org/onlinedocs/gcc/C-Dialect-Options.html](https://gcc.gnu.org/onlinedocs/gcc/C-Dialect-Options.html)
    *   GNU Make Manual: [https://www.gnu.org/software/make/manual/](https://www.gnu.org/software/make/manual/)
*   **C++:**
    *   ISO C++ Standard Committee: [https://isocpp.org/](https://isocpp.org/) (News, FAQs, Core Guidelines)
    *   cppreference.com: [https://en.cppreference.com/w/](https://en.cppreference.com/w/) (Excellent C and C++ reference)
    *   "A Tour of C++" by Bjarne Stroustrup (Good overview of modern C++)
    *   Effective Modern C++ (Book by Scott Meyers)
    *   CMake Documentation: [https://cmake.org/documentation/](https://cmake.org/documentation/)
    *   C++ Core Guidelines: [https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)