# How to securily use ADO Feed Tokens

Using Azure DevOps Feed Tokens securely is crucial to prevent unauthorized access and ensure the integrity of your CI/CD pipelines. Here’s a step-by-step guide on how to securely use Azure DevOps Feed Tokens:

#### Step 1: Generate a Personal Access Token (PAT)
1. Navigate to Azure DevOps:
- Go to your Azure DevOps organization URL (e.g., https://dev.azure.com/yourorganization).
2. Create a PAT:
- Click on your user profile icon at the top right corner.
- Select "Personal access tokens".
- Click "New Token".
- Set the name, expiration date, and select the scopes required for your feed (e.g., Packaging (Read) for read access to feeds).
- Click "Create" and save the generated token securely (e.g., in a password manager).
#### Step 2: Store the PAT Securely
1. Use Azure Key Vault:
- Store the PAT in Azure Key Vault to ensure it is encrypted and access-controlled.
- Follow the Azure Key Vault documentation to create a Key Vault and store secrets.
2. Configure Access to the Key Vault:
- Ensure your Azure DevOps service principal or managed identity has access to the Key Vault.
- Set access policies in the Key Vault to allow get permissions for secrets.
#### Step 3: Access the PAT in Azure DevOps Pipelines
1. Set up a Service Connection:
- In Azure DevOps, go to your project settings.
- Navigate to "Service connections" under "Pipelines".
- Create a new service connection for Azure Key Vault and provide the necessary details (subscription, Key Vault name, and select the managed identity or service principal).
2. Use the Secret in Your Pipeline:
- Edit your pipeline YAML file to include steps to fetch the PAT from Azure Key Vault.
- Example YAML snippet:
```yaml 
trigger:  
- main  

pool:  
  vmImage: 'ubuntu-latest'  

variables:  
  FEED_PAT: $(FeedPAT)  

steps:  
- task: AzureKeyVault@1  
  inputs:  
    azureSubscription: '<Your Service Connection>'  
    KeyVaultName: '<Your Key Vault Name>'  
    SecretsFilter: 'FeedPAT'  
    RunAsPreJob: true  

- script: |  
    echo "Setting up environment..."  
    export FEED_PAT=$(FEED_PAT)  
    # Your build or deployment script that uses the FEED_PAT  
  displayName: 'Setup Environment'  
``` 

#### Step 4: Use the Token in Your Scripts
1. Environment Variable:
- In your scripts (e.g., shell scripts, PowerShell scripts), reference the environment variable that holds the PAT.
- Example:
```bash
#!/bin/bash  
echo "Using feed token..."  
nuget sources add -name "MyFeed" -source "https://pkgs.dev.azure.com/yourorganization/_packaging/yourfeed/nuget/v3/index.json" -username "any" -password "$FEED_PAT"  
``` 
#### 2. Ensure PAT is Not Logged:

- Avoid logging the PAT in your build logs to prevent exposure.
- Ensure any command that uses the PAT does not output it to the console.
#### Step 5: Regularly Rotate Tokens
- Regularly rotate your PATs and update the secrets in Azure Key Vault to minimize the risk of token leakage.
- Monitor and audit the use of PATs in your pipelines and adjust permissions as needed.
#### Additional Resources
- [Azure DevOps Personal Access Tokens (PATs)](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access

