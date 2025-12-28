### Write a simple C++ program and a Dockerfile to run it?

Sure, here's a simple C++ program which will print out "Hello, Docker!" to the console:

Filename: main.cpp

```cpp
#include <iostream>

int main() {
    std::cout << "Hello, Docker!" << std::endl;
    return 0;
}
```

Now, we need to create a Dockerfile that will compile and run this program. Here is a simple Dockerfile:

Filename: Dockerfile

```dockerfile
# Use an official lightweight C++ runtime as a parent image
FROM gcc:latest

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy the current directory contents into the container
COPY . .

# Compile the C++ program
RUN g++ -o output main.cpp

# Run the output program when the container launches
CMD ["./output"]
```

This Dockerfile starts from the gcc:latest image (which has gcc preinstalled), sets the working directory to `/usr/src/app`, copies the current directory . (where your main.cpp and Dockerfile are located) into the image, compiles the C++ program using g++, and then runs the compiled program when a container is launched from the image.

To build the Docker image, navigate to the directory containing the project files (main.cpp and Dockerfile) and run this command:

```bash
docker build -t cpp_docker_app .
```

To run the Docker container:

```bash
docker run -it cpp_docker_app
```

You should see the output "Hello, Docker!" printed to the console.
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
### Write a simple C++ program and a Dockerfile to run it?
Sure, here is a simple C++ program and Dockerfile to run it.

C++ Program (main.cpp):

```cpp
#include<iostream>

int main() {
    std::cout << "Hello World from Docker container!";
    return 0;
}
```

To compile and run this program in Docker, you would need a Dockerfile. Here is a simple Dockerfile for the program:

```Dockerfile
# We are going to use the official GCC image from Docker Hub
FROM gcc:latest

# Define the working directory
WORKDIR /usr/src/app

# Copy the current directory contents into the container at /usr/src/app
COPY . .

# Compile the program
RUN g++ -o my_program main.cpp

# Run the program when the container launches
CMD ["./my_program"]
```

To build and run this Dockerfile, you would run the following commands:

```bash
# Build the Docker image
docker build -t my_c++_program .

# Run the Docker container
docker run -it --rm my_c++_program
```

Note: All these commands should be run from the directory where the `main.cpp` and the Dockerfile are located. The `docker build` command builds a Docker image from a Dockerfile and the `docker run` command runs a Docker container from a Docker image. The `-t` option in the `docker build` command is used to tag the image with a name. The `-it` option in the `docker run` command is used to run the container in interactive mode and the `--rm` option is used to automatically remove the container when it exits.


#### Write a simple C++ program and a Dockerfile to run it?

Sure, I can help you with that.

Here's a simple C++ program:

```cpp
// HelloWorld.cpp
#include<iostream>
using namespace std;
int main()
{
    cout<<"Hello, World!"<<endl;
    return 0;
}
```

Now to run this program in a Docker container, we need to create a Dockerfile. Here's a simple Dockerfile:

```dockerfile
FROM ubuntu:18.04

# Install g++, the C++ compiler
RUN apt-get update && apt-get install -y \
    g++

# Copy the C++ file into the Docker container. You may need to adjust the path
# depending on where you saved the file.
COPY HelloWorld.cpp .

# Compile the C++ file
RUN g++ -o HelloWorld HelloWorld.cpp

# Run the compiled program
CMD ["./HelloWorld"]
```

You can build and run the Docker image as follows:

```bash
docker build -t hello-world .
docker run hello-world
```

This will compile and run the `HelloWorld.cpp` file in a Docker container. The output should be "Hello, World!".