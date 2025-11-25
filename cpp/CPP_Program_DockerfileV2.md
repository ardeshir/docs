### Write a simple C++ program and a Dockerfile to run it? 

Sure, I can definitely guide you on how to accomplish this.

First off, let's write a simple C++ program. Let's call it `main.cpp`:

```cpp
#include <iostream>

int main() {
    std::cout << "Hello from Docker container!\n";
    return 0;
}
```

Next, we need to create a `Dockerfile` that builds and runs this program. Here is an example:

```Dockerfile
# Use the official g++ runtime as a parent image
FROM gcc:latest

# Set the working directory in the container to /app
WORKDIR /app

# Copy the current directory contents into the container at /app
ADD . /app

# Compile the C++ program
RUN g++ -o output main.cpp

# Run the output program when the container launches
CMD ["./output"]
```

Here's a brief explanation of what the `Dockerfile` does:

- `FROM gcc:latest` - This line specifies the parent image from which we are building. In this case, we are using the latest version of gcc.
- `WORKDIR /app` - This line sets the working directory inside the container. All subsequent actions (run, cmd, add, copy) will be taken from the perspective of this directory.
- `ADD . /app` - This line copies new files, directories or remote file URLs from `<src>` and adds them to the filesystem of the image at the path `<dest>`.
- `RUN g++ -o output main.cpp` - This line compiles the C++ file `main.cpp` to an executable called `output`.
- `CMD ["./output"]` - This line provides defaults for an executing container. In this case, it runs the compiled C++ program when the Docker image is run.

After you have both `main.cpp` and the `Dockerfile` in the same directory, you can build and run the Docker image using the following commands:

1. Build the Docker image: `docker build -t my-cpp-app .`
2. Run the Docker image: `docker run -it --rm my-cpp-app`

The `-t` flag in the `docker build` command tags our image. The `--rm` flag in the `docker run` command automatically cleans up the container and removes the file system when the container exits.


 #### Write a simple C++ program and a Dockerfile to run it? 

Sure, first let's create a simple C++ program.

**main.cpp:**

```cpp
#include <iostream>

int main() {
    std::cout << "Hello from Docker container!" << std::endl;
    return 0;
}
```

This program will just print "Hello from Docker container!" to the console.

Now, we need to create a Dockerfile to build and run our C++ program inside a Docker container.

**Dockerfile:**

```Dockerfile
FROM gcc:latest

WORKDIR /app

ADD . /app

RUN g++ -o output main.cpp

CMD ["./output"]
```

This Dockerfile does the following:

1. Pulls the latest GCC image from Docker Hub. GCC is the GNU Compiler Collection, which includes a C++ compiler.
2. Sets `/app` as the working directory inside the container.
3. Copies the content of the current directory on your host to the `/app` directory in the Docker container.
4. Compiles `main.cpp` using g++ and creates an executable named `output`.
5. Runs the `output` executable when the Docker container is started.

To build and run this Docker application, you need to have Docker installed on your computer. Then, you can use the following commands in the terminal:

1. Build the Docker image: `docker build -t cppapp .`
2. Run the Docker container: `docker run cppapp`

The `-t` option in the `docker build` command is used to tag the image with a name. In this case, the name is `cppapp`. The `.` specifies that the Dockerfile is in the current directory.

The `docker run` command is used to start a new container from an image. In this case, it starts a new container from the `cppapp` image.