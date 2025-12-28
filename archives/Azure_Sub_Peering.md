# VNet Peering Across Azure Tenants

### Is there is a way to do cross Azure tenant vnet peering?
between azure subscriptions, for instance, enable VNET connectivity between a "cantina sub" vnet and a "fsdi sub" vnet? 

Yes, it is possible to do cross Azure tenant VNet peering. You can peer virtual networks across different Azure subscriptions and even across different Azure Active Directory (Azure AD) tenants. This can be done using Azure's virtual network peering feature.

Here is a high-level overview of the process & prerequisites:

**Permissions:**  
- You need to have the Network Contributor role in both subscriptions.
- Subscription ID and VNet Information: You need the subscription ID and VNet details (name, resource group, and address space) for both VNets.

1. **Prepare Network Details**: Collect details about the peering VNets, such as their Resource IDs and subscription information.

2. **Authorize Peering**: Initiate the peering from one VNet and authorize it on the other.

3. **Create Peering**: Complete the peering connection by setting necessary properties and enabling the peering.

### Steps to Configure Cross-Tenant VNet Peering

1. **Set up User Permissions**:
    - Ensure that users in both tenants have the necessary permissions:
        - Azure AD directory reader permissions.
        - Network Contributor rights on the VNets to be peered.

2. **Initiate Peering in Azure Portal**:
    - Go to the virtual network in the source subscription.
    - Under "Settings," select "Peerings" and then "Add."
    - Provide the Resource ID of the target VNet (found in the properties of the target VNet).
    - Configure peering settings as needed (e.g., allow forwarded traffic, gateway transit).

3. **Authorize Peering in Target Subscription**:
    - For the target VNet, you will find a pending peering request.
    - Accept or authorize the peering request, and configure reciprocal settings if necessary.

4. **Verification**:
    - Verify that the peering status is "Connected" on both VNets.
    - Test connectivity across the peered VNets.

### Example Using Azure CLI

You can also accomplish this using the Azure CLI:

```sh
# Variables
resourceGroup1="SourceResourceGroup"
vnetName1="SourceVNet"
resourceGroup2="TargetResourceGroup"
vnetName2="TargetVNet"
subscription1="SourceSubscriptionID"
subscription2="TargetSubscriptionID"
peeringName1="PeeringFromSourceToTarget"
peeringName2="PeeringFromTargetToSource"

# Switch to the source subscription
az account set --subscription $subscription1

# Get VNet Ids
vnet1Id=$(az network vnet show --resource-group $resourceGroup1 --name $vnetName1 --query id --output tsv)
vnet2Id=$(az network vnet show --resource-group $resourceGroup2 --name $vnetName2 --query id --output tsv)

# Create peering from source to target
az network vnet peering create \
  --name $peeringName1 \
  --resource-group $resourceGroup1 \
  --vnet-name $vnetName1 \
  --remote-vnet $vnet2Id \
  --allow-vnet-access

# Switch to the target subscription
az account set --subscription $subscription2

# Create peering from target to source
az network vnet peering create \
  --name $peeringName2 \
  --resource-group $resourceGroup2 \
  --vnet-name $vnetName2 \
  --remote-vnet $vnet1Id \
  --allow-vnet-access
```

### Resources
For more detailed steps, refer to the official Azure documentation:
- [Virtual network peering](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview)
- [Cross-tenant virtual network peering](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-peering#create-a-peer-using-the-portal)

