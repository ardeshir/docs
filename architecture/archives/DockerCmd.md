### How to Build and Push

Commands you need to build a Docker image, tag it, and push it to DockerHub:
- Build a Docker Image:
- You need to navigate to the directory that contains your Dockerfile and run the following command:

`docker build -t your_image_name . `
 
- This command will build a Docker image from your Dockerfile and tag (-t) it with the name your_image_name.
- Tag a Docker Image
##### After the image has been created, you can tag it using the docker tag command:

`docker tag your_image_name:latest your_dockerhub_username/your_image_name:version`

- This command will tag your image with your DockerHub username and the version you want to assign to it.
- Push the Docker Image to DockerHub:

Before you push the image, you need to login to DockerHub from your command line using:

`docker login`  
- Enter your DockerHub credentials and then you can push your image using:

`docker push your_dockerhub_username/your_image_name:version`
  
- This command will push your tagged image to your DockerHub repository.

- Replace `your_image_name`, `your_dockerhub_username`, and version with your actual image name, DockerHub username, and the version you want to assign to your image.
