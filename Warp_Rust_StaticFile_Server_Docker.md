# Rust Static File Server with Warp & Docker

### Write a simple Rust Server that can server MarkDown files from wwwroot directory, and a Dockerfile to run this program? 

Sure! Below is an example of a simple Rust server using the `warp` library to serve Markdown files from a `wwwroot` directory. We'll also include a `Dockerfile` to build and run the server inside a Docker container.

### Rust Server Code (`main.rs`)

First, you'll need to add the necessary dependencies to your `Cargo.toml`:

```toml
[dependencies]
warp = "0.3"
tokio = { version = "1", features = ["full"] }
```

Now, create your `main.rs` file:

```rust
use warp::Filter;
use std::convert::Infallible;
use tokio::fs::File;
use tokio::io::AsyncReadExt;

#[tokio::main]
async fn main() {
    // Define the route to serve Markdown files
    let markdown_route = warp::path!("wwwroot" / String)
        .and_then(serve_markdown);

    // Start the server
    warp::serve(markdown_route)
        .run(([0, 0, 0, 0], 3030))
        .await;
}

async fn serve_markdown(file_name: String) -> Result<impl warp::Reply, Infallible> {
    // Construct the file path
    let file_path = format!("wwwroot/{}", file_name);

    // Try to open the file
    match File::open(file_path).await {
        Ok(mut file) => {
            let mut contents = String::new();
            file.read_to_string(&mut contents).await.unwrap();
            Ok(warp::reply::html(contents))
        }
        Err(_) => {
            // Return a 404 if the file is not found
            Ok(warp::reply::with_status(
                "File not found".to_string(),
                warp::http::StatusCode::NOT_FOUND,
            ))
        }
    }
}
```

### Dockerfile

Next, create a `Dockerfile` to build the Rust server and run it in a container:

```Dockerfile
# Use the official Rust image as the base image
FROM rust:latest

# Create a new directory for the application
WORKDIR /app

# Copy the Cargo.toml and Cargo.lock files
COPY Cargo.toml Cargo.lock ./

# Create the Cargo build directory to cache dependencies
RUN cargo build --release && rm -rf src

# Copy the source code
COPY src ./src

# Build the application
RUN cargo build --release

# Copy the wwwroot directory
COPY wwwroot ./wwwroot

# Set the entrypoint command to run the application
CMD ["./target/release/your_rust_server"]
```

### Directory Structure

Ensure your project has the following structure:

```plaintext
your_project/
├── Dockerfile
├── Cargo.toml
├── Cargo.lock
├── src/
│   └── main.rs
└── wwwroot/
    └── example.md
```

### Building and Running the Docker Container

1. Build the Docker image:

   ```sh
   docker build -t rust-markdown-server .
   ```

2. Run the Docker container:

   ```sh
   docker run -p 3030:3030 rust-markdown-server
   ```

After running the container, you can access your Markdown files by visiting `http://localhost:3030/wwwroot/example.md` in your browser.

Feel free to modify the file paths and content as needed for your specific use case.
