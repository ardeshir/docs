az functionapp show --resource-group rg-fsdi-unity-dev --name app-fn-changefeed-fsdi-unity-dev --query "{name:name, appId:identity.principalId, systemAssigned:identity.type=='SystemAssigned'}"
