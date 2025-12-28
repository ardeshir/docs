# Cpp API Service dockerized 

o build and run your C++ service using Docker, follow these steps:

1. **Create the Dockerfile**
2. **Build the Docker image**
3. **Run the Docker container locally**
4. **Push the Docker image to Docker Hub**

Below is a step-by-step guide with the corresponding commands and files:

### Step 1: Create the Dockerfile

Create a file called `Dockerfile` in the root of your project directory and add the following content:

```Dockerfile
# Use the official Ubuntu base image
FROM ubuntu:20.04

# Install required packages
RUN apt-get update && apt-get install -y \
    g++ \
    cmake \
    make \
    wget \
    libboost-all-dev

# Install nlohmann/json and yhirose/cpp-httplib via git
RUN apt-get install -y git
RUN mkdir /includes
RUN cd /includes && git clone https://github.com/nlohmann/json.git
RUN cd /includes && git clone https://github.com/yhirose/cpp-httplib.git

# Set the working directory
WORKDIR /usr/src/app

# Copy the CMakeLists.txt and source files into the container
COPY ./CMakeLists.txt ./CMakeLists.txt
COPY ./src ./src
COPY ./include ./include

# Build the project
RUN cmake . && make

# Set environment variables for server host and port
ENV SERVER_HOST=0.0.0.0
ENV SERVER_PORT=8000

# Expose the server port
EXPOSE 8000

# Run the service
CMD ["./JuliaToCpp"]
```

### Step 2: Build the Docker Image

Next, build the Docker image using the Dockerfile you just created. Open a terminal, navigate to the directory containing the Dockerfile, and run the following command:

```sh
docker build -t your-dockerhub-username/juliatocpp:latest .
```

### Step 3: Run the Docker Container Locally

To test the service locally, run the Docker container with the following command:

```sh
docker run -p 8000:8000 your-dockerhub-username/juliatocpp:latest
```

This command maps port `8000` on your host machine to port `8000` of the container, making the service accessible at `http://localhost:8000`.

### Step 4: Push the Docker Image to Docker Hub

Before pushing your Docker image to Docker Hub, ensure that you are logged in. If not, log into Docker Hub using the following command:

```sh
docker login
```

Provide your Docker Hub username and password when prompted. Once logged in, push the Docker image to Docker Hub:

```sh
docker push your-dockerhub-username/juliatocpp:latest
```

Here, `your-dockerhub-username` should be replaced with your actual Docker Hub username.

You can now pull and run this image on any machine with Docker installed by using the following command:

```sh
docker run -p 8000:8000 your-dockerhub-username/juliatocpp:latest
```

This completes the setup of creating, building, running, and pushing your Dockerized C++ service.
