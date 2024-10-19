# Azure Container Apps, how can I set the "minimum replicas" to 2

On Azure Container Apps, you can configure scaling rules, including setting the minimum number of replicas to ensure that at least a certain number of instances are always running. Here's how you can set the "minimum replicas" value to 2 for your container app using the Azure CLI:

1. **Install the Azure CLI and ensure it’s up to date** if you haven’t already:
    ```sh
    az upgrade
    ```
2. **Login to your Azure Account**:
    ```sh
    az login
    ```
3. **Set the Azure subscription** you want to use:
    ```sh
    az account set --subscription "YOUR_SUBSCRIPTION_ID"
    ```

4. **Update the container app configuration** to set the minimum replicas. 

Here’s an example command to update the existing container app configuration to set the minimum replicas to 2:

```sh
az containerapp update \
  --name <CONTAINER_APP_NAME> \
  --resource-group <RESOURCE_GROUP_NAME> \
  --set template.scale.minReplicas=2
```

Replace `<CONTAINER_APP_NAME>` with the actual name of your container app, and `<RESOURCE_GROUP_NAME>` with the name of the resource group containing your container app.

### Verification
After updating, you can verify the current configuration by describing the container app:

```sh
az containerapp show \
  --name <CONTAINER_APP_NAME> \
  --resource-group <RESOURCE_GROUP_NAME>
```

Look for the `template.scale.minReplicas` field in the output to confirm it’s set to 2.

### References
- Azure CLI documentation for `az containerapp update`: [Azure CLI Documentation](https://learn.microsoft.com/en-us/cli/azure/containerapp?view=azure-cli-latest)
- Container App scaling concepts: [Azure Container Apps Scaling](https://learn.microsoft.com/en-us/azure/container-apps/scale)
