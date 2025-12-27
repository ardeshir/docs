# How to deploy a Docker image to Azure Function App

Deploying a Docker image to an Azure Function App using an Azure DevOps pipeline involves several steps, including building the Docker image, pushing it to a container registry, and then deploying it to the Azure Function App. Below are the detailed steps along with an example of a pipeline (`azure-pipelines.yml`) script:

### Prerequisites

1. **Azure Subscription:** You need an Azure subscription.
2. **Azure Function App:** You need an existing Azure Function App configured to use a custom Docker container.
3. **Container Registry:** You need a container registry to store your Docker images (e.g., Azure Container Registry (ACR), Docker Hub).

### Steps

1. **Set up your Azure DevOps pipeline.**
2. **Build and push the Docker image.**
3. **Deploy the Docker image to the Azure Function App.**

### Example `azure-pipelines.yml`

Here’s an example of the pipeline script:

```yaml
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

variables:
  # Container Registry variables
  ACR_NAME: 'yourACR' # Azure Container Registry name
  IMAGE_NAME: 'myfunctionappimage'

  # Azure Function App variables
  FUNCTION_APP_NAME: 'myfunctionapp'
  RESOURCE_GROUP: 'myresourcegroup'
  SERVICE_CONNECTION_NAME: 'myServiceConnection'

steps:

# Step 1: Checkout the code
- task: Checkout@1
  displayName: 'Checkout Code'
  inputs:
    repository: $(Build.Repository.Name)
    persistCredentials: true

# Step 2: Login to Azure Container Registry
- task: AzureCLI@2
  displayName: 'Login to Azure Container Registry'
  inputs:
    azureSubscription: $(SERVICE_CONNECTION_NAME)
    scriptType: bash
    scriptLocation: inlineScript
    inlineScript: |
      az acr login --name $(ACR_NAME)

# Step 3: Build Docker image
- task: Docker@2
  displayName: 'Build Docker image'
  inputs:
    command: build
    repository: $(ACR_NAME).azurecr.io/$(IMAGE_NAME)
    Dockerfile: '**/Dockerfile'
    buildContext: .
    tags: |
      $(Build.BuildId)

# Step 4: Push Docker image
- task: Docker@2
  displayName: 'Push Docker image'
  inputs:
    command: push
    repository: $(ACR_NAME).azurecr.io/$(IMAGE_NAME)
    tags: |
      $(Build.BuildId)

# Step 5: Deploy Docker image to Azure Function App
- task: AzureCLI@2
  displayName: 'Deploy Docker image to Azure Function App'
  inputs:
    azureSubscription: $(SERVICE_CONNECTION_NAME)
    scriptType: bash
    scriptLocation: inlineScript
    inlineScript: |
      az functionapp config container set \
        --name $(FUNCTION_APP_NAME) \
        --resource-group $(RESOURCE_GROUP) \
        --docker-custom-image-name $(ACR_NAME).azurecr.io/$(IMAGE_NAME):$(Build.BuildId) \
        --docker-registry-server-url https://$(ACR_NAME).azurecr.io

```

### Explanation of the Steps

1. **Trigger and Pool:**
   - The pipeline triggers on changes to the `main` branch and uses an Ubuntu VM image.

2. **Variables:**
   - Define variables for the ACR name, image name, function app name, resource group, and service connection.

3. **Checkout Code:**
   - Checkout the repository code to build the Docker image.

4. **Login to ACR:**
   - Use the Azure CLI to log in to the Azure Container Registry.

5. **Build Docker Image:**
   - Use the Docker task to build the Docker image from the Dockerfile in your repository.

6. **Push Docker Image:**
   - Use the Docker task to push the Docker image to your Azure Container Registry.

7. **Deploy Docker Image to Azure Function App:**
   - Use the Azure CLI to set the custom Docker image for your Azure Function App to the newly pushed image.

### Additional References

- **Azure Function App Deployment:** [Azure CLI functionapp config container](https://docs.microsoft.com/en-us/cli/azure/functionapp/config/container?view=azure-cli-latest)
- **Azure DevOps Docker Task:** [Docker@2 task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/build/docker?view=azure-pipelines)

This should cover the complete process for deploying a Docker image to an Azure Function App using an Azure DevOps pipeline. Ensure that your service connection in Azure DevOps has sufficient permissions to perform these actions on your Azure resources.
