### Write a simple C++ program and a Dockerfile to run it?

Sure, here is a simple C++ program and a Dockerfile to run it.

The C++ program (`main.cpp`):

```cpp
#include <iostream>

int main() {
    std::cout << "Hello, Docker!" << std::endl;
    return 0;
}
```

To compile and run this C++ program, you can use g++, a GNU Compiler Collection (GCC) for C++. 

The Dockerfile:

```dockerfile
FROM gcc:8.1.0

WORKDIR /usr/src/app

COPY . .

RUN g++ -o output main.cpp

CMD ["./output"]
```

This Dockerfile does the following:
- Pulls the gcc:8.1.0 image from the Docker Hub. This image includes the GCC, which can compile C and C++ programs.
- Sets /usr/src/app as the working directory.
- Copies the contents from your current directory (on your machine) to the current directory in the image (i.e., /usr/src/app).
- Runs g++ to compile the C++ file (main.cpp) into an executable file (output).
- Specifies that Docker should execute the "./output" command when the container launches.

To build and run this Dockerfile:

1. Save the C++ program as `main.cpp` in your current directory.
2. Save the Dockerfile in your current directory.
3. Build the Docker image by running `docker build -t cpp_program .` in the terminal.
4. Run the Docker container by running `docker run cpp_program` in the terminal.
