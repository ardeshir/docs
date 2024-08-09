### Write a simple C++ program and a Dockerfile to run it?Sure, here's a simple C++ program that prints "Hello, World!" and a Dockerfile to run it.

Here is the C++ program in a file named `main.cpp`:

```cpp
#include<iostream>
using namespace std;

int main() {
    cout << "Hello, World!" << endl;
    return 0;
}
```

Next, you need a Dockerfile to set up the environment, compile, and run the program. Here's a basic Dockerfile:

```Dockerfile
# Use the official gcc image as base
FROM gcc:latest

# Set the working directory
WORKDIR /app

# Copy the C++ file into the container
COPY main.cpp .

# Compile the C++ file
RUN g++ main.cpp -o output

# Run the output file
CMD ["./output"]
```

To build and run the Docker container:

1. Save the C++ program in a file called `main.cpp`.
2. Save the Dockerfile in the same directory as `main.cpp`.
3. Run `docker build -t my_cpp_app .` in your terminal to build the Docker image.
4. Run `docker run -it --rm my_cpp_app` to run the C++ program in a Docker container.

This will create a Docker image with the GCC compiler, copy your source code into the image, compile it into an executable file named `output`, and run it when the container is started.
