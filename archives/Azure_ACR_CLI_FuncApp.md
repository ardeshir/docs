# ACR Creation and Pipeline deployment

Certainly! Here's a step-by-step guide on how to create an Azure Container Registry (ACR), build and tag a Docker image, push it to ACR, and then deploy your images using Azure CLI commands.   
  
### Step 1: Create an Azure Container Registry (ACR)  
   
1. **Login to Azure**  
   ```sh  
   az login  
   ```  
   
2. **Create a Resource Group**  
   ```sh  
   az group create --name myResourceGroup --location eastus  
   ```  
   
3. **Create the ACR**  
   ```sh  
   az acr create --resource-group myResourceGroup --name myACRRegistry --sku Basic  
   ```  
   
### Step 2: Log in to Azure Container Registry (ACR)  
   
1. **Login to the ACR**  
   ```sh  
   az acr login --name myACRRegistry  
   ```  
   
### Step 3: Build and Tag the Docker Image  
   
1. **Navigate to the Directory Containing Your Dockerfile**  
   ```sh  
   cd /path/to/your/project  
   ```  
   
2. **Build the Docker Image**  
   ```sh  
   docker build -t myapp:latest .  
   ```  
   
3. **Tag the Docker Image**  
   ```sh  
   docker tag myapp:latest myacrregistry.azurecr.io/myapp:latest  
   ```  
   
### Step 4: Push the Docker Image to ACR  
   
1. **Push the Docker Image**  
   ```sh  
   docker push myacrregistry.azurecr.io/myapp:latest  
   ```  
   
### Step 5: Deploy to Azure Function App  
   
1. **Create an Azure Function App**  
   ```sh  
   az functionapp create --resource-group myResourceGroup --name myFunctionApp --storage-account <your-storage-account> --plan <your-app-service-plan> --deployment-container-image-name myacrregistry.azurecr.io/myapp:latest  
   ```  
   
2. **Update the Function App Configuration to Use the ACR Image**  
   ```sh  
   az functionapp config container set --name myFunctionApp --resource-group myResourceGroup --docker-custom-image-name myacrregistry.azurecr.io/myapp:latest  
   ```  
   
### Step-by-Step Summary of Azure DevOps Pipeline Configuration  
   
After setting up the ACR and pushing your Docker image, you can configure your Azure DevOps pipeline as follows:  
   
1. **Create or Update the Azure DevOps Pipeline YAML File**  
   ```yaml  
   trigger:  
   - main  # or your specific branch  
  
   pool:  
     vmImage: 'ubuntu-latest'  
  
   variables:  
     # Set the registry name and image name  
     dockerRegistryServiceConnection: '<Your-Service-Connection-Name>'  
     imageRepository: 'myacrregistry.azurecr.io/myapp'  
     imageTag: '$(Build.BuildId)'  
  
   steps:  
   - task: Docker@2  
     inputs:  
       containerRegistry: '$(dockerRegistryServiceConnection)'  
       repository: '$(imageRepository)'  
       command: 'buildAndPush'  
       Dockerfile: '**/Dockerfile'  
       tags: |  
         $(imageTag)  
  
   - task: AzureWebAppContainer@1  
     inputs:  
       azureSubscription: '<Your-Azure-Subscription-Name>'  
       appName: '<Your-Function-App-Name>'  
       imageName: '$(imageRepository):$(imageTag)'  
   ```  
   
Replace the placeholders with your actual values:  
- `<Your-Service-Connection-Name>`: The name of the ACR service connection in Azure DevOps.  
- `<Your-Azure-Subscription-Name>`: The name of your Azure subscription.  
- `<Your-Function-App-Name>`: The name of your Azure Function App.  
   
### Summary  
   
1. **Create an ACR**: Use Azure CLI to create an Azure Container Registry.  
2. **Login to ACR**: Authenticate
