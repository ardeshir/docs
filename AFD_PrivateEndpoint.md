# AzureFrontDoor Private Enpoint 

The problem:  Bicep template doesn't account for the Private Endpoint (PE) that was created through the portal; deployments overwrite the Front Door configuration and lose the PE connection.

Strategies to resolve this:

## Strategy 1: Reference Existing Private Endpoint and Configure Origin

```bicep
// Reference the existing Private Endpoint created by the portal
// NEW PE for dev-cnc-ui
// Reference the existing Private Endpoint created by the portal
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: 'stfsdiunitydevui001'
  scope: resourceGroup('a3cfee58-9860-4304-8f70-04e60a850479', 'rg-fsdi-unity-dev')
}

resource origin_dev_cnc_ui 'Microsoft.Cdn/profiles/origingroups/origins@2022-11-01-preview' = {
  parent: originGroup_dev_cnc_ui
  name: 'dev-cnc-ui'
  properties: {
    hostName: 'stfsdiunitydevui001.z13.web.core.windows.net'
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 50
    originHostHeader:'stfsdiunitydevui001.z13.web.core.windows.net'
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true 
    sharedPrivateLinkResource: {
      privateLink:{
        id: storageAccount.id  // Use constructed resource ID
        }
      groupId: 'web'
      privateLinkLocation: 'East US' // Match your region
      requestMessage: 'Front Door private link connection'
      status: 'Approved'
    }
  } 
  dependsOn: []
}

```

## Strategy 2: Conditional Deployment with Resource Existence Check

```bicep
// Parameters to control behavior
param usePrivateLink bool = true
param privateEndpointResourceGroup string = 'eafd-Prod-eastus'
param privateEndpointName string = '2d2eb87d-45c9-440f-9438-c9cd94befe1d'

// Conditionally reference existing PE
resource existingPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' existing = if (usePrivateLink) {
  name: privateEndpointName
  scope: resourceGroup(privateEndpointResourceGroup)
}

resource origin_dev_cnc_ui 'Microsoft.Cdn/profiles/origingroups/origins@2022-11-01-preview' = {
  parent: originGroup_dev_cnc_ui
  name: 'dev-cnc-ui'
  properties: union({
    hostName: 'stfsdiunitydevui001.z13.web.core.windows.net'
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 50
    originHostHeader: 'stfsdiunitydevui001.z13.web.core.windows.net'
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }, usePrivateLink ? {
    privateLinkResource: {
      id: existingPrivateEndpoint.id
      privateLinkLocation: 'East US'
      requestMessage: 'Front Door private link connection'
    }
  } : {})
}
```

## Strategy 3: Import Existing PE Configuration into Bicep

If you want full control, you can recreate the PE in your Bicep template:

```bicep
// First, get details about your storage account that the PE connects to
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: 'stfsdiunitydevui001'
  // Add scope if in different RG
}

// Define the Private Endpoint in Bicep (this will import the existing one)
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: '2d2eb87d-45c9-440f-9438-c9cd94befe1d'
  location: 'East US'
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'storageConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'web' // For blob storage web endpoint
          ]
          requestMessage: 'Front Door Connection'
        }
      }
    ]
    subnet: {
      id: '/subscriptions/c1bc5dd7-ea97-469c-89fa-8f26624902fd/resourceGroups/your-vnet-rg/providers/Microsoft.Network/virtualNetworks/your-vnet/subnets/your-subnet'
    }
  }
}
```

## Recommended Approach

I recommend **Strategy 1** because:
1. It preserves the existing PE without recreating it
2. It's the least disruptive to your current setup
3. It clearly documents the dependency in your IaC

## Additional Considerations

1. **API Version**: Make sure you're using a recent API version that supports private link properties
2. **Permissions**: Ensure your deployment identity has read permissions on the PE resource group
3. **Testing**: Test in a non-production environment first
4. **Documentation**: Document the PE dependency for your team

## Validation Steps

After implementing, verify:
1. The Front Door deployment completes successfully
2. The PE connection remains active
3. Traffic flows through the private connection
4. No public access is allowed (if that was your intent)

 
