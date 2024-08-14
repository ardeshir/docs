Response: 
Sure, here is a simple Rust application and a Dockerfile to run it.

Let's start by creating a simple Rust application. We will create a new project named "hello_world" with the command `cargo new hello_world`. 

Here is the main.rs file:

```rust
// src/main.rs

fn main() {
    println!("Hello, world!");
}
```
This application simply prints out "Hello, world!" when run.

Next, we need to create a Dockerfile in the project root directory:

```Dockerfile
# We're using the official Rust image as base image
FROM rust:1.52 as builder

# Create a new empty shell project
RUN USER=root cargo new --bin hello_world

WORKDIR /hello_world

# Copy over your Manifest files
COPY ./Cargo.lock ./Cargo.lock
COPY ./Cargo.toml ./Cargo.toml

# This build step will cache your dependencies
RUN cargo build --release
RUN rm src/*.rs

# Copy your source files
COPY ./src ./src

# Build for release.
RUN rm ./target/release/deps/hello_world*
RUN cargo build --release

# Our second stage, that creates the final minimal image
FROM debian:buster-slim

# Copy the build artifact from the builder stage
COPY --from=builder /hello_world/target/release/hello_world .

# Set the binary as the entrypoint of the container
CMD ["./hello_world"]
```

This Dockerfile does the following:

1. Sets up a Rust environment
2. Creates a new Rust binary project
3. Copies your project's manifest files over and builds your dependencies
4. Copies over your source code and builds the application
5. Sets up a minimal final stage
6. Copies over the built application from the builder stage
7. Sets the application as the entrypoint of the container

To build and run this Docker image, you can use these commands:

```bash
docker build -t hello_world .
docker run -it hello_world
```

The Docker build command creates a Docker image using the Dockerfile and tags it as "hello_world". The Docker run command runs a new container using the "hello_world" image and provides an interactive shell into the container.