#### Given this Error: "InvalidTemplateDeployment:
The template deployment failed with error: 'Authorization failed for template resource '2b551088-d511-5732-91cb-27e49a5830ba' of type 'Microsoft.Authorization/roleAssignments'. The client '16b403c7-2a32-4c7b-9ab6-0133df971e61' with object id '16b403c7-2a32-4c7b-9ab6-0133df971e61' does not have permission to perform action 'Microsoft.Authorization/roleAssignments/write' at scope '/subscriptions/990e4ca5-8623-4ca2-be4e-fda2e8adc350/resourceGroups/rg-cds-appisnight/providers/Microsoft.ContainerRegistry/registries/croptmzsb/providers/Microsoft.Authorization/roleAssignments/2b551088-d511-5732-91cb-27e49a5830ba'" 

How I know what this guid [16b403c7-2a32-4c7b-9ab6-0133df971e61] displayed in Azure Pipeline is referring to, and how can I find out what client need the role added? 

#### Permissins need to be set

This GUID (`16b403c7-2a32-4c7b-9ab6-0133df971e61`) values represent, in the context of Azure, a Service Principal Id/Object Id. Service Principals are the application equivalent of a user, as in, a user logs into an app to get to Azure and a Service Principal 'logs in' to an app to access Azure resources. Any application that wants to access Azure resources needs to authenticate with Azure Active Directory using a Service Principal.

To resolve the issue stated, it seems like your service principal doesn't have the required permissions to perform the action `Microsoft.Authorization/roleAssignments/write`, meaning that it does not have the necessary Role-Based Access Control (RBAC) permissions.

To verify this, you can lookup this Service Principal and evaluate its permissions. 

Here is how you can look it up in Azure Active Directory:

1. Login to the Azure portal.
2. In the left navigation pane, select Azure Active Directory.
3. In the Azure Active Directory blade, select Enterprise Applications.
4. In the Enterprise Applications blade, find the Application where Application (client) ID matches the provided GUID.

If you find the given GUID in the list, this signifies that the ID belongs to this Service Principal.

To assign the role, follow these steps:

1. Navigate to the Azure resource you want to assign the role to.
2. Select Access control (IAM).
3. Click on "+ Add" and then "Add role assignment".
4. In the Role drop-down list, select the appropriate role such as "Contributor".
5. In the Select text box, enter the name of the application to which you want to assign the role.
6. After the application name appears in the list, select it and then click Save.

For more information, you can refer to this guide: https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal
