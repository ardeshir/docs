# C++ code to interact with the database

### Creating the PostgreSQL Database and Tables

Create the PostgreSQL database and the required tables.

1. **Connect to your PostgreSQL instance**:
    ```sh
    psql -U your_username -d your_dbname
    ```

2. **Create the tables**:
    ```sql
    CREATE TABLE urls (
        id SERIAL PRIMARY KEY,
        url TEXT NOT NULL,
        last_checked TIMESTAMP NOT NULL
    );

    CREATE TABLE content (
        id SERIAL PRIMARY KEY,
        url_id INTEGER REFERENCES urls(id),
        content TEXT,
        last_checked TIMESTAMP
    );
    ```

### C++ Code to Interact with PostgreSQL Database

- C++ application to perform the necessary tasks. You will need the PostgreSQL client library `libpqxx` to interact with the database.

1. **Install the `libpqxx` library**:

    On Ubuntu:
    ```sh
    sudo apt-get update
    sudo apt-get install libpqxx-dev
    ```

    On other systems, you might need to install it via the package manager or from source.

2. **Create `fetch.cpp`**:

    ```cpp
    #include <iostream>
    #include <pqxx/pqxx>
    #include <thread>
    #include <chrono>
    #include <ctime>

    void fetch_and_update(pqxx::connection& C) {
        while (true) {
            try {
                pqxx::work W(C);

                std::string query = "SELECT id, url FROM urls WHERE last_checked < NOW() - INTERVAL '24 hours' LIMIT 1;";
                pqxx::result R = W.exec(query);

                if (R.empty()) {
                    std::cout << "No URLs found. Sleeping for 1 minute." << std::endl;
                    std::this_thread::sleep_for(std::chrono::minutes(1));
                    continue;
                }

                for (auto row: R) {
                    int id = row["id"].as<int>();
                    std::string url = row["url"].as<std::string>();

                    std::cout << "Fetching URL: " << url << std::endl;

                    // Placeholder for fetching content
                    std::string fetched_content = "<html>Example content</html>";

                    std::string content_query = "INSERT INTO content (url_id, content, last_checked) VALUES (" + W.quote(id) + ", " + W.quote(fetched_content) + ", NOW()) ON CONFLICT (url_id) DO UPDATE SET content=EXCLUDED.content, last_checked=NOW();";
                    W.exec(content_query);

                    std::string update_query = "UPDATE urls SET last_checked = NOW() WHERE id = " + W.quote(id) + ";";
                    W.exec(update_query);

                    W.commit();
                }
            } catch (const std::exception& e) {
                std::cerr << e.what() << std::endl;
            }
        }
    }

    int main(int argc, char* argv[]) {
        const std::string connection_str = "dbname=your_dbname user=your_username password=your_password hostaddr=127.0.0.1 port=5432";

        try {
            pqxx::connection C(connection_str);
            if (C.is_open()) {
                std::cout << "Connected to " << C.dbname() << std::endl;
                fetch_and_update(C);
            } else {
                std::cerr << "Can't open database" << std::endl;
                return 1;
            }
        } catch (const std::exception& e) {
            std::cerr << e.what() << std::endl;
            return 1;
        }
        return 0;
    }
    ```

### CMakeLists.txt

Create a `CMakeLists.txt` file to build the project.

```text
cmake_minimum_required(VERSION 3.10)
project(fetch_service)

set(CMAKE_CXX_STANDARD 11)
find_package(PkgConfig REQUIRED)
pkg_check_modules(PQXX REQUIRED libpqxx)

include_directories(${PQXX_INCLUDE_DIRS})
link_directories(${PQXX_LIBRARY_DIRS})

add_executable(fetch_service fetch.cpp)

target_link_libraries(fetch_service ${PQXX_LIBRARIES})
```

### Building the Project

1. **Create required directories**:
    ```sh
    mkdir build
    cd build
    ```

2. **Run CMake to generate build files**:
    ```sh
    cmake ..
    ```

3. **Build the project**:
    ```sh
    make
    ```

4. **Run your application**:
    ```sh
    ./fetch_service
    ```

Remember to replace placeholders for database name, user, and password with real values. The actual fetching of URLs and parsing their content is left as a placeholder, you can use libraries such as `libcurl` for fetching and `gumbo-parser` for parsing HTML content if you aim to expand the functionality further.
