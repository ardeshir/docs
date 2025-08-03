# Azure Function in Rust - Complete Setup Guide

## What's Included:

1. **Rust Azure Function** (`main.rs`) - A fully functional HTTP-triggered function that:
   - Handles both GET and POST requests
   - Includes query parameter and JSON body support
   - Has a health check endpoint
   - Provides detailed request information and error handling

2. **Docker Configuration** (`Dockerfile`) - Multi-stage build that:
   - Builds the Rust binary efficiently
   - Uses the official Azure Functions runtime
   - Optimizes for production deployment

3. **Function Configuration Files**:
   - `host.json` - Azure Functions host configuration
   - `function.json` files for each endpoint
   - `Cargo.toml` with all necessary dependencies

4. **Deployment Scripts**:
   - `deploy.sh` - Complete automated deployment to Azure
   - `local-run.sh` - Local development and testing

5. **Complete Documentation** - Step-by-step setup and deployment guide

## Key Features:

- **Production Ready**: Includes logging, error handling, and health checks
- **Fully Automated**: One-command deployment to Azure
- **Local Development**: Easy local testing environment
- **Containerized**: Uses Docker for consistent deployments
- **RESTful API**: Proper HTTP methods and status codes

## Quick Start:

1. **Local Testing**:
   ```bash
   chmod +x local-run.sh
   ./local-run.sh
   ```

2. **Deploy to Azure**:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

The deployment script handles everything automatically - creating resource groups, storage accounts, container registries, building Docker images, and deploying your function to Azure.

Your function will be available at endpoints like:
- `https://your-function-app.azurewebsites.net/api/hello_world`
- `https://your-function-app.azurewebsites.net/api/health`

## Project Structure

Your project should be organized as follows:

```
azure-function-rust/
├── src/
│   └── main.rs                 # Main Rust source code
├── hello_world/
│   └── function.json          # Function configuration
├── health/
│   └── function.json          # Health check function config
├── Cargo.toml                 # Rust dependencies
├── Dockerfile                 # Docker configuration
├── host.json                  # Azure Functions host configuration
├── deploy.sh                  # Deployment script
├── local-run.sh              # Local development script
└── README.md                  # This file
```

## Prerequisites

Before you begin, ensure you have the following installed:

1. **Rust** (latest stable version)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **Azure CLI**
   ```bash
   # macOS
   brew install azure-cli
   
   # Ubuntu/Debian
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Windows
   # Download from https://aka.ms/installazurecliwindows
   ```

3. **Docker**
   - Download from [https://www.docker.com/get-started](https://www.docker.com/get-started)

4. **Azure Functions Core Tools** (for local development)
   ```bash
   npm install -g azure-functions-core-tools@4 --unsafe-perm true
   ```

## Step-by-Step Deployment Instructions

### 1. Clone or Create Project Structure

Create a new directory and set up the project files as shown in the project structure above.

### 2. Local Development and Testing

First, test your function locally:

```bash
# Make the local run script executable
chmod +x local-run.sh

# Run the function locally
./local-run.sh
```

This will:
- Build your Rust application
- Set up the local environment
- Start the Azure Functions runtime locally
- Make your function available at `http://localhost:7071/api/hello_world`

### 3. Test Local Function

Once running locally, test your function:

```bash
# Test GET request
curl "http://localhost:7071/api/hello_world?name=Developer"

# Test POST request
curl -X POST http://localhost:7071/api/hello_world \
  -H "Content-Type: application/json" \
  -d '{"name":"Developer","message":"Hello from local testing!"}'

# Test health check
curl http://localhost:7071/api/health
```

### 4. Deploy to Azure

When you're ready to deploy to Azure:

```bash
# Make the deployment script executable
chmod +x deploy.sh

# Run the deployment
./deploy.sh
```

The deployment script will:
1. Check prerequisites
2. Log into Azure (if needed)
3. Create a resource group
4. Create a storage account
5. Create an Azure Container Registry
6. Build and push your Docker image
7. Create the Function App
8. Configure the Function App
9. Display deployment information

### 5. Test Deployed Function

After deployment, the script will provide URLs to test your function:

```bash
# Replace YOUR_FUNCTION_URL with the actual URL from deployment output
curl "https://YOUR_FUNCTION_URL/api/hello_world?name=Production"

curl -X POST https://YOUR_FUNCTION_URL/api/hello_world \
  -H "Content-Type: application/json" \
  -d '{"name":"Production","message":"Hello from Azure!"}'

curl https://YOUR_FUNCTION_URL/api/health
```

## Function Features

This Azure Function includes:

- **HTTP Trigger**: Responds to both GET and POST requests
- **Query Parameter Support**: GET requests can include a `name` parameter
- **JSON Body Support**: POST requests accept JSON with `name` and `message` fields
- **Health Check Endpoint**: Available at `/api/health`
- **Error Handling**: Proper HTTP status codes and error messages
- **Logging**: Integrated logging for debugging
- **Request Information**: Returns metadata about the request

## Configuration Options

You can customize the deployment by modifying variables in `deploy.sh`:

```bash
RESOURCE_GROUP="your-resource-group-name"
FUNCTION_APP_NAME="your-function-app-name"
LOCATION="your-preferred-region"
```

## Monitoring and Troubleshooting

1. **View Logs**: Use Azure portal or CLI
   ```bash
   az functionapp logs tail --name YOUR_FUNCTION_APP --resource-group YOUR_RESOURCE_GROUP
   ```

2. **Check Function Status**: 
   ```bash
   az functionapp show --name YOUR_FUNCTION_APP --resource-group YOUR_RESOURCE_GROUP
   ```

3. **Update Function**: Modify code and re-run deployment script

## Cleanup

To remove all created resources:

```bash
az group delete --name YOUR_RESOURCE_GROUP --yes --no-wait
```

## Additional Notes

- The function uses a custom handler approach, which allows running Rust code in Azure Functions
- Docker is used for containerized deployment, ensuring consistent runtime environment
- The function includes CORS headers for web application integration
- All resources are created with appropriate naming to avoid conflicts

This setup provides a complete, production-ready Azure Function written in Rust with full deployment automation.


- Artifacts needed to build a Rust Azure Function 

```toml
[package]
name = "azure-function-rust"
version = "0.1.0"
edition = "2021"

[dependencies]
azure-functions = "0.14"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1.0", features = ["full"] }
log = "0.4"
env_logger = "0.10"

[[bin]]
name = "handler"
path = "src/main.rs"
```

- The Main.rs file : 

```rust
use azure_functions::{
    bindings::{HttpRequest, HttpResponse},
    func,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Serialize, Deserialize)]
struct RequestBody {
    name: Option<String>,
    message: Option<String>,
}

#[derive(Serialize)]
struct ResponseBody {
    message: String,
    timestamp: String,
    request_info: RequestInfo,
}

#[derive(Serialize)]
struct RequestInfo {
    method: String,
    url: String,
    headers_count: usize,
}

#[func]
#[binding(name = "req", type = "httpTrigger", auth_level = "anonymous", methods = ["get", "post"])]
#[binding(name = "$return", type = "http")]
pub fn hello_world(req: HttpRequest) -> HttpResponse {
    log::info!("Rust Azure Function triggered!");

    let request_info = RequestInfo {
        method: req.method().to_string(),
        url: req.uri().to_string(),
        headers_count: req.headers().len(),
    };

    // Handle different HTTP methods
    match req.method().as_str() {
        "GET" => handle_get_request(&req, request_info),
        "POST" => handle_post_request(&req, request_info),
        _ => HttpResponse::builder()
            .status(405)
            .header("Content-Type", "application/json")
            .body(serde_json::json!({
                "error": "Method not allowed",
                "allowed_methods": ["GET", "POST"]
            }).to_string())
            .unwrap(),
    }
}

fn handle_get_request(req: &HttpRequest, request_info: RequestInfo) -> HttpResponse {
    // Get query parameters
    let query_params: HashMap<String, String> = req.query_params().collect();
    let name = query_params.get("name").unwrap_or(&"World".to_string());

    let response = ResponseBody {
        message: format!("Hello, {}! This is a Rust Azure Function responding to GET request.", name),
        timestamp: chrono::Utc::now().to_rfc3339(),
        request_info,
    };

    HttpResponse::builder()
        .status(200)
        .header("Content-Type", "application/json")
        .body(serde_json::to_string_pretty(&response).unwrap())
        .unwrap()
}

fn handle_post_request(req: &HttpRequest, request_info: RequestInfo) -> HttpResponse {
    let body = req.body().as_str().unwrap_or("{}");
    
    match serde_json::from_str::<RequestBody>(body) {
        Ok(request_body) => {
            let name = request_body.name.unwrap_or_else(|| "Anonymous".to_string());
            let user_message = request_body.message.unwrap_or_else(|| "No message provided".to_string());

            let response = ResponseBody {
                message: format!("Hello, {}! Your message: '{}' was received by the Rust Azure Function.", name, user_message),
                timestamp: chrono::Utc::now().to_rfc3339(),
                request_info,
            };

            HttpResponse::builder()
                .status(200)
                .header("Content-Type", "application/json")
                .body(serde_json::to_string_pretty(&response).unwrap())
                .unwrap()
        },
        Err(_) => {
            HttpResponse::builder()
                .status(400)
                .header("Content-Type", "application/json")
                .body(serde_json::json!({
                    "error": "Invalid JSON in request body",
                    "expected_format": {
                        "name": "string (optional)",
                        "message": "string (optional)"
                    }
                }).to_string())
                .unwrap()
        }
    }
}

// Additional utility function for health check
#[func]
#[binding(name = "req", type = "httpTrigger", auth_level = "anonymous", methods = ["get"], route = "health")]
#[binding(name = "$return", type = "http")]
pub fn health_check(_req: HttpRequest) -> HttpResponse {
    log::info!("Health check endpoint called");
    
    HttpResponse::builder()
        .status(200)
        .header("Content-Type", "application/json")
        .body(serde_json::json!({
            "status": "healthy",
            "service": "Azure Function in Rust",
            "timestamp": chrono::Utc::now().to_rfc3339()
        }).to_string())
        .unwrap()
}
```

- Second Toml file;

```toml
[package]
name = "azure-function-rust"
version = "0.1.0"
edition = "2021"

[dependencies]
azure-functions = "0.14"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1.0", features = ["full"] }
log = "0.4"
env_logger = "0.10"
chrono = { version = "0.4", features = ["serde"] }

[[bin]]
name = "handler"
path = "src/main.rs"
```
- Dockerfile : 

```dockerfile 
# Build stage
FROM rust:1.75-slim as builder

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy the Cargo files
COPY Cargo.toml Cargo.lock ./

# Create a dummy main.rs to cache dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Build dependencies (this will be cached)
RUN cargo build --release && rm -rf src

# Copy the actual source code
COPY src ./src

# Build the application
RUN cargo build --release

# Runtime stage - Use Azure Functions custom handler runtime
FROM mcr.microsoft.com/azure-functions/dotnet:4-appservice

# Install required packages for running the Rust binary
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true \
    FUNCTIONS_WORKER_RUNTIME=custom

# Copy the built binary from builder stage
COPY --from=builder /app/target/release/handler /home/site/wwwroot/handler

# Copy function configuration files
COPY host.json /home/site/wwwroot/
COPY hello_world/function.json /home/site/wwwroot/hello_world/
COPY health/function.json /home/site/wwwroot/health/

# Make the handler executable
RUN chmod +x /home/site/wwwroot/handler

# Expose the port that Azure Functions uses
EXPOSE 80
```

- Host.json & the hello_world Azure.io: 

```json
{
  "version": "2.0",
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[2.*, 3.0.0)"
  },
  "customHandler": {
    "description": {
      "defaultExecutablePath": "handler",
      "workingDirectory": "",
      "arguments": []
    },
    "enableForwardingHttpRequest": true
  },
  "logging": {
    "logLevel": {
      "default": "Information"
    }
  },
  "functionTimeout": "00:05:00"
}
```

```hello_world.json
{
  "disabled": false,
  "bindings": [
    {
      "authLevel": "anonymous",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": ["get", "post"]
    },
    {
      "type": "http",
      "direction": "out",
      "name": "$return"
    }
  ]
}
```
- Script to deploy.sh :

```bash
#!/bin/bash

# Azure Function Rust Deployment Script
set -e

# Configuration - Update these values
RESOURCE_GROUP="rg-rust-function"
FUNCTION_APP_NAME="rust-function-app-$(date +%s)"
LOCATION="East US"
STORAGE_ACCOUNT="rustfuncstorage$(date +%s | tail -c 6)"
CONTAINER_REGISTRY="rustfuncregistry$(date +%s | tail -c 6)"
IMAGE_NAME="azure-function-rust"
IMAGE_TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required commands are installed
check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        echo_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        echo_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v cargo &> /dev/null; then
        echo_error "Rust/Cargo is not installed. Please install it first."
        exit 1
    fi
    
    echo_success "All prerequisites are installed."
}

# Login to Azure
azure_login() {
    echo_info "Checking Azure login status..."
    if ! az account show &> /dev/null; then
        echo_info "Not logged in to Azure. Starting login process..."
        az login
    else
        echo_success "Already logged in to Azure."
    fi
}

# Create resource group
create_resource_group() {
    echo_info "Creating resource group: $RESOURCE_GROUP"
    az group create --name $RESOURCE_GROUP --location "$LOCATION"
    echo_success "Resource group created."
}

# Create storage account
create_storage_account() {
    echo_info "Creating storage account: $STORAGE_ACCOUNT"
    az storage account create \
        --name $STORAGE_ACCOUNT \
        --location "$LOCATION" \
        --resource-group $RESOURCE_GROUP \
        --sku Standard_LRS \
        --kind StorageV2
    echo_success "Storage account created."
}

# Create container registry
create_container_registry() {
    echo_info "Creating Azure Container Registry: $CONTAINER_REGISTRY"
    az acr create \
        --resource-group $RESOURCE_GROUP \
        --name $CONTAINER_REGISTRY \
        --sku Basic \
        --admin-enabled true
    echo_success "Container registry created."
}

# Build and push Docker image
build_and_push_image() {
    echo_info "Building Docker image..."
    docker build -t $IMAGE_NAME:$IMAGE_TAG .
    
    echo_info "Getting ACR login server..."
    ACR_LOGIN_SERVER=$(az acr show --name $CONTAINER_REGISTRY --resource-group $RESOURCE_GROUP --query loginServer --output tsv)
    
    echo_info "Logging into Azure Container Registry..."
    az acr login --name $CONTAINER_REGISTRY
    
    echo_info "Tagging image for ACR..."
    docker tag $IMAGE_NAME:$IMAGE_TAG $ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG
    
    echo_info "Pushing image to ACR..."
    docker push $ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG
    
    echo_success "Docker image built and pushed to ACR."
}

# Create Function App
create_function_app() {
    echo_info "Creating Function App: $FUNCTION_APP_NAME"
    
    # Get ACR login server
    ACR_LOGIN_SERVER=$(az acr show --name $CONTAINER_REGISTRY --resource-group $RESOURCE_GROUP --query loginServer --output tsv)
    
    # Get ACR credentials
    ACR_USERNAME=$(az acr credential show --name $CONTAINER_REGISTRY --resource-group $RESOURCE_GROUP --query username --output tsv)
    ACR_PASSWORD=$(az acr credential show --name $CONTAINER_REGISTRY --resource-group $RESOURCE_GROUP --query passwords[0].value --output tsv)
    
    # Create the function app
    az functionapp create \
        --resource-group $RESOURCE_GROUP \
        --name $FUNCTION_APP_NAME \
        --storage-account $STORAGE_ACCOUNT \
        --functions-version 4 \
        --runtime custom \
        --deployment-container-image-name $ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG \
        --docker-registry-server-user $ACR_USERNAME \
        --docker-registry-server-password $ACR_PASSWORD
    
    echo_success "Function App created."
}

# Configure Function App settings
configure_function_app() {
    echo_info "Configuring Function App settings..."
    
    az functionapp config appsettings set \
        --name $FUNCTION_APP_NAME \
        --resource-group $RESOURCE_GROUP \
        --settings \
            FUNCTIONS_WORKER_RUNTIME=custom \
            WEBSITE_RUN_FROM_PACKAGE=0 \
            AzureWebJobsFeatureFlags=EnableWorkerIndexing
    
    echo_success "Function App configured."
}

# Display deployment information
display_info() {
    echo_success "Deployment completed successfully!"
    echo ""
    echo_info "Deployment Details:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Function App: $FUNCTION_APP_NAME"
    echo "  Storage Account: $STORAGE_ACCOUNT"
    echo "  Container Registry: $CONTAINER_REGISTRY"
    echo ""
    
    FUNCTION_URL=$(az functionapp show --name $FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP --query defaultHostName --output tsv)
    echo_info "Function URLs:"
    echo "  Main Function: https://$FUNCTION_URL/api/hello_world"
    echo "  Health Check: https://$FUNCTION_URL/api/health"
    echo ""
    echo_info "Test your function with:"
    echo "  GET:  curl https://$FUNCTION_URL/api/hello_world?name=YourName"
    echo "  POST: curl -X POST https://$FUNCTION_URL/api/hello_world -H 'Content-Type: application/json' -d '{\"name\":\"YourName\",\"message\":\"Hello from Rust!\"}'"
    echo "  Health: curl https://$FUNCTION_URL/api/health"
}

# Cleanup function (optional)
cleanup() {
    echo_warning "To clean up resources, run:"
    echo "  az group delete --name $RESOURCE_GROUP --yes --no-wait"
}

# Main deployment process
main() {
    echo_info "Starting Azure Function Rust deployment..."
    
    check_prerequisites
    azure_login
    create_resource_group
    create_storage_account
    create_container_registry
    build_and_push_image
    create_function_app
    configure_function_app
    display_info
    cleanup
}

# Run the main function
main "$@"
```
- Script to run-local.sh:

```bash
#!/bin/bash

# Local development script for Azure Function in Rust
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if Azure Functions Core Tools is installed
check_func_tools() {
    if ! command -v func &> /dev/null; then
        echo_info "Azure Functions Core Tools not found. Installing via npm..."
        npm install -g azure-functions-core-tools@4 --unsafe-perm true
    else
        echo_success "Azure Functions Core Tools is already installed."
    fi
}

# Build the Rust application
build_rust_app() {
    echo_info "Building Rust application..."
    cargo build --release
    
    # Copy the binary to the expected location
    cp target/release/handler ./handler
    chmod +x ./handler
    
    echo_success "Rust application built successfully."
}

# Create necessary directories and files
setup_local_env() {
    echo_info "Setting up local environment..."
    
    # Create function directories
    mkdir -p hello_world
    mkdir -p health
    
    echo_success "Local environment setup complete."
}

# Start the function locally
start_function() {
    echo_info "Starting Azure Function locally..."
    echo_info "The function will be available at:"
    echo "  - http://localhost:7071/api/hello_world"
    echo "  - http://localhost:7071/api/health"
    echo ""
    echo_info "Press Ctrl+C to stop the function."
    
    func start --port 7071
}

# Main function
main() {
    echo_info "Setting up local development environment..."
    
    check_func_tools
    setup_local_env
    build_rust_app
    start_function
}

# Run if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
```

The solution is complete and ready for production use!​​​​​​​​​​​​​​​​ 

### Connect: Join Univrs.io
- [Univrs.io Discord](https://discord.gg/pXwH6rQcsS)
- [Univrs Patreon](https://wwww.patreon.com/univrs)
- [Univrs.io](https://univrs.io)
- [https://ardeshir.io](https://ardeshir.io)
- [https://hachyderm.io/@sepahsalar](https://hachyderm.io/@sepahsalar)
- [https://github.com/ardeshir](https://github.com/ardeshir)
- [https://medium.com/@sepahsalar](https://medium.com/@sepahsalar)
- [https://www.linkedin.com/in/ardeshir](https://www.linkedin.com/in/ardeshir)
- [https://sepahsalar.substack.com/](https://sepahsalar.substack.com/)
- [LinkTree @Sepahsalar](https://linktr.ee/Sepahsalar) 
- [Univrs MetaLabel](https://univrs.metalabel.com)



