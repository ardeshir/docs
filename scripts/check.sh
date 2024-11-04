az functionapp show --resource-group rg-fsdi-unity-canary --name app-fn-changefeed-fsdi-unity-canary --query "{name:name, appId:identity.principalId, systemAssigned:identity.type=='SystemAssigned'}"
