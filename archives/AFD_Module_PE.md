# AzureFrontDoor Private Endpoint Module

The right approach for proper Infrastructure as Code:  Managing everything through Bicep is  cleaner and more maintainable than having a mix of manual and automated resources.

Comprehensive strategy:

## Step 1: Clean Up and Plan

**Delete the manual PE in Dev:**
```bash
# Remove the manually created PE
az network private-endpoint delete --name "2d2eb87d-45c9-440f-9438-c9cd94befe1d" --resource-group "eafd-Prod-eastus"
```

## Step 2: Complete Bicep Template with PE Creation

```bicep
// Parameters for environment and configuration
param environment string = 'dev'
param productName string = 'cnc-ui'
param location string = resourceGroup().location
param vnetResourceGroup string
param vnetName string
param subnetName string
param storageAccountName string
param storageAccountResourceGroup string = resourceGroup().name

// Generate consistent naming
var privateEndpointName = 'pe-${productName}-${environment}-${location}'
var privateDnsZoneName = 'privatelink.web.core.windows.net'

// Reference existing infrastructure
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  name: subnetName
  parent: vnet
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
  scope: resourceGroup(storageAccountResourceGroup)
}

// Create Private DNS Zone (or reference existing)
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
}

// Link DNS Zone to VNet
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Create the Private Endpoint
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: privateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'web'
          ]
          requestMessage: 'Front Door private connection for ${productName}-${environment}'
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    subnet: {
      id: subnet.id
    }
    customDnsConfigs: []
  }
}

// Create DNS Zone Group for automatic DNS registration
resource privateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-web-core-windows-net'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// Front Door Profile
resource profile 'Microsoft.Cdn/profiles@2022-11-01-preview' = {
  name: 'afd-${productName}-${environment}'
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'  // Premium required for Private Link
  }
  properties: {
    originResponseTimeoutSeconds: 240
  }
}

// Origin Group
resource originGroup 'Microsoft.Cdn/profiles/origingroups@2022-11-01-preview' = {
  parent: profile
  name: 'og-${productName}-${environment}'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

// Origin with Private Link
resource origin 'Microsoft.Cdn/profiles/origingroups/origins@2022-11-01-preview' = {
  parent: originGroup
  name: '${productName}-${environment}'
  properties: {
    hostName: '${storageAccountName}.z13.web.core.windows.net'
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 50
    originHostHeader: '${storageAccountName}.z13.web.core.windows.net'
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
    // Configure Private Link Origin
    sharedPrivateLinkResource: {
      privateLink: {
        id: storageAccount.id
      }
      privateLinkLocation: location
      requestMessage: 'Front Door connection for ${productName}-${environment}'
      status: 'Approved'  // This will auto-approve in same subscription
    }
  }
  dependsOn: [
    privateEndpoint
  ]
}

// Outputs for reference
output privateEndpointId string = privateEndpoint.id
output frontDoorProfileId string = profile.id
output privateDnsZoneId string = privateDnsZone.id
```

## Step 3: Environment-Specific Parameters Files

**dev.parameters.json:**
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {"value": "dev"},
    "productName": {"value": "cnc-ui"},
    "vnetResourceGroup": {"value": "rg-network-dev"},
    "vnetName": {"value": "vnet-dev-eastus"},
    "subnetName": {"value": "subnet-privateendpoints"},
    "storageAccountName": {"value": "stfsdiunitydevui001"},
    "storageAccountResourceGroup": {"value": "rg-storage-dev"}
  }
}
```

## Step 4: Reusable Module for Multiple Products

Create a **modules/frontdoor-with-pe.bicep** module:

```bicep
// This becomes your reusable module
@description('Environment name')
param environment string

@description('Product name')
param productName string

@description('Storage account name')
param storageAccountName string

// ... rest of parameters

// ... all the resources from above

// Module outputs
output frontDoorEndpoint string = profile.properties.frontDoorId
output privateEndpointFqdn string = privateEndpoint.properties.customDnsConfigs[0].fqdn
```

**Main template using the module:**
```bicep
// Deploy multiple products using the module
module cncUi 'modules/frontdoor-with-pe.bicep' = {
  name: 'cnc-ui-deployment'
  params: {
    environment: environment
    productName: 'cnc-ui'
    storageAccountName: 'stfsdiunitydevui001'
    // ... other params
  }
}

module productTwo 'modules/frontdoor-with-pe.bicep' = {
  name: 'product-two-deployment'
  params: {
    environment: environment
    productName: 'product-two'
    storageAccountName: 'stproducttwouistore'
    // ... other params
  }
}
```

## Step 5: CI/CD Pipeline (Azure DevOps example)

```yaml
# azure-pipelines.yml
trigger:
- main

variables:
- group: 'frontdoor-variables'

stages:
- stage: Dev
  jobs:
  - job: DeployDev
    steps:
    - task: AzureResourceManagerTemplateDeployment@3
      inputs:
        deploymentScope: 'Resource Group'
        azureResourceManagerConnection: 'Azure-ServiceConnection'
        subscriptionId: 'c1bc5dd7-ea97-469c-89fa-8f26624902fd'
        action: 'Create Or Update Resource Group'
        resourceGroupName: 'rg-frontdoor-dev'
        location: 'East US'
        templateLocation: 'Linked artifact'
        csmFile: 'main.bicep'
        csmParametersFile: 'parameters/dev.parameters.json'
        deploymentMode: 'Incremental'

- stage: Test
  dependsOn: Dev
  condition: succeeded()
  jobs:
  - job: DeployTest
    steps:
    # Similar deployment for Test environment

- stage: Prod
  dependsOn: Test
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - job: DeployProd
    # Add manual approval here
    steps:
    # Production deployment
```

## Step 6: Handle Private Endpoint Approval

For **same subscription** deployments, the connection is typically auto-approved. For **cross-subscription** scenarios, you can:

```bicep
// For manual approval scenarios, remove the status property
sharedPrivateLinkResource: {
  privateLink: {
    id: storageAccount.id
  }
  privateLinkLocation: location
  requestMessage: 'Front Door connection for ${productName}-${environment}'
  // status: 'Approved' // Remove this for manual approval
}
```

Then add an approval step in your pipeline:
```yaml
- task: AzureCLI@2
  displayName: 'Approve Private Endpoint Connection'
  inputs:
    azureSubscription: 'Azure-ServiceConnection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      # Get the connection ID and approve it
      az network private-endpoint-connection approve \
        --resource-name $(storageAccountName) \
        --resource-group $(resourceGroupName) \
        --name $(privateEndpointConnectionName) \
        --type Microsoft.Storage/storageAccounts
```

## Benefits of This Approach

1. **Consistent**: All environments managed the same way
2. **Scalable**: Easy to add new products/environments
3. **Auditable**: All changes tracked in Git
4. **Repeatable**: Can recreate any environment
5. **Secure**: Private endpoints managed as code

This approach will save you significant manual work and ensure consistency across all your environments and products!
