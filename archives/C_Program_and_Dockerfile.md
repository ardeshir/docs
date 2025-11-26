### C program that prints "Hello World" and a Dockerfile that can be used to compile and run it.

Here is the C program, let's call it `hello.c`:

```c
#include <stdio.h>

int main() {
    printf("Hello, World!\n");
    return 0;
}
```

Here is the Dockerfile:

```dockerfile
FROM gcc:latest

WORKDIR /app

COPY . .

RUN gcc -o hello hello.c

CMD ["./hello"]
```

This Dockerfile does the following:

1. It uses the latest gcc image from Docker Hub as a base. GCC is the GNU Compiler Collection, which includes front ends for C, C++, Objective-C, Fortran, Ada, Go, and D, as well as libraries for these languages.

2. It sets the working directory in the container to /app. This means that all subsequent commands will be run in this directory.

3. It copies all files from the current directory on your local machine to the current directory in the container.

4. It compiles the hello.c file into an executable called hello.

5. It sets the default command to run when the container starts to be ./hello, which runs the hello program.

To build the Docker image, you can use this command in the directory containing the Dockerfile and hello.c:

```bash
docker build -t hello-c-program .
```

And to run the Docker container, you can use this command:

```bash
docker run -it --rm hello-c-program
```

This command will print "Hello, World!" to the console.
