##### Q: Query for params and create an App Sevice Plan, and Web App with bash?

A: 
```bash
#!/bin/bash  
  
# List Azure accounts and ask user to choose one  
accounts=$(az account list --query "[].{name:name, id:id}" --output tsv)  
IFS=$'\n' accounts=($accounts)  
echo "Choose az account:"  
for index in "${!accounts[@]}"; do  
    echo "$index - ${accounts[index]}"  
done  
read -p "Enter the number of the account to use: " account_num  
  
# Set the chosen account as active  
account_id=$(echo ${accounts[$account_num]} | awk '{print $2}')  
az account set --subscription $account_id  
  
# Ask for parameters  
read -p "Enter RG name to create: " RESOURCE_GROUP  
read -p "Enter the Region for this RG: " AZURE_REGION  
read -p "Enter the App Service Plan name: " AZURE_APP_PLAN  
read -p "Enter the Web App Name: " AZURE_WEB_APP  
read -p "Enter the URL for Git to deploy: " GITREPOURL  
  
# Create resource group  
az group create --name $RESOURCE_GROUP --location $AZURE_REGION  
  
# Wait for the resource group to be created  
az resource wait --name $RESOURCE_GROUP --resource-type "Microsoft.Resources/resourceGroups" --exists  
  
# Create App Service Plan  
az appservice plan create --name $AZURE_APP_PLAN --resource-group $RESOURCE_GROUP --location $AZURE_REGION --sku FREE  
  
# Wait for the App Service Plan to be created  
az resource wait --name $AZURE_APP_PLAN --resource-type "Microsoft.Web/serverFarms" --resource-group $RESOURCE_GROUP --exists  
  
# Create Web App  
az webapp create --name $AZURE_WEB_APP --resource-group $RESOURCE_GROUP --plan $AZURE_APP_PLAN  
  
# Wait for the Web App to be created  
az resource wait --name $AZURE_WEB_APP --resource-type "Microsoft.Web/sites" --resource-group $RESOURCE_GROUP --exists  
  
# Other commands  
az appservice plan list --output table  --resource-group $RESOURCE_GROUP
az webapp list --output table  --resource-group $RESOURCE_GROUP
site="http://$AZURE_WEB_APP.azurewebsites.net"  
echo $site  
  
curl $AZURE_WEB_APP.azurewebsites.net  
az webapp deployment source config --name $AZURE_WEB_APP --resource-group $RESOURCE_GROUP --repo-url $GITREPOURL --branch master --manual-integration  
```


##Single Account A: 
```bash 

#!/bin/bash  
  
# Ask for parameters  
read -p "Enter RG name to create: " RESOURCE_GROUP  
read -p "Enter the Region for this RG: " AZURE_REGION  
read -p "Enter the App Service Plan name: " AZURE_APP_PLAN  
read -p "Enter the Web App Name: " AZURE_WEB_APP  
read -p "Enter the URL for Git to deploy: " GITREPOURL  
  
# Create resource group  
az group create --name $RESOURCE_GROUP --location $AZURE_REGION  
  
# Wait for the resource group to be created  
az resource wait --name $RESOURCE_GROUP --resource-type "Microsoft.Resources/resourceGroups" --exists  
  
# Create App Service Plan  
az appservice plan create --name $AZURE_APP_PLAN --resource-group $RESOURCE_GROUP --location $AZURE_REGION --sku FREE  
  
# Wait for the App Service Plan to be created  
az resource wait --name $AZURE_APP_PLAN --resource-type "Microsoft.Web/serverFarms" --resource-group $RESOURCE_GROUP --exists  
  
# Create Web App  
az webapp create --name $AZURE_WEB_APP --resource-group $RESOURCE_GROUP --plan $AZURE_APP_PLAN  
  
# Wait for the Web App to be created  
az resource wait --name $AZURE_WEB_APP --resource-type "Microsoft.Web/sites" --resource-group $RESOURCE_GROUP --exists  
  
# Other commands  
az appservice plan list --output table  
az webapp list --output table  
site="http://$AZURE_WEB_APP.azurewebsites.net"  
echo $site  
  
curl $AZURE_WEB_APP.azurewebsites.net  
az webapp deployment source config --name $AZURE_WEB_APP --resource-group $RESOURCE_GROUP --repo-url $GITREPOURL --branch master --manual-integration  

```


