##### Q: How do I find the Feed Alphabetic name and project form this ID Azure DevOps Feed ID 
vstsFeed: bb377ee2-33c8-4866-a55d-cbb0f72346e2/30ed9892-ac99-4342-9647-3afea3dc4ef5 ?


A: The Azure DevOps Feed ID you have provided appears to be in the format of vstsFeed: {projectId}/{feedId}. This ID is commonly used when you are dealing with Azure Artifacts feeds.

However, directly from this ID, you can't extract the feed alphabetic name and the project name. This ID contains the project ID and feed ID which are both GUIDs.

To get the project name and the feed name, you'll need to use Azure DevOps REST API.

Here are the general steps you'll need to follow:
Get the Project name from the Project ID:

You can use the following API to get the project name:
GET https://dev.azure.com/{organization}/{projectId}/_apis/projects/{projectId}?api-version=6.0  
 
Replace {organization} and {projectId} with your actual organization name and project ID.

The response will contain the project name.

2. Get the Feed name from the Feed ID:

You can use the following API to get the feed name:
GET https://feeds.dev.azure.com/fsdi/_apis/packaging/feeds/30ed9892-ac99-4342-9647-3afea3dc4ef5?api-version=7.1-preview.1  
 
Replace {organization} and {feedId} with your actual organization name and feed ID.

The response will contain the feed name.

Remember to replace {organization}, {projectId}, and {feedId} with the values from your Feed ID.

Also note that these APIs require authentication. If you're running these from a script, you'll likely need to create a Personal Access Token (PAT) with appropriate permissions and use it to authenticate your requests.

Please refer to Azure DevOps documentation for more information and specific details about the API usage and authentication:

https://learn.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-6.0

to get the name of the Project and Feed from a Azure DevOps Feed ID, you can use the Azure DevOps REST API.

Here is an example of how you can do this using curl:
curl -u username:pat_token https://feeds.dev.azure.com/{organization}/{project}/_apis/packaging/feeds/{feedId}?api-version=6.1-preview.1  
 
In the above URL:
Replace {organization} with your Azure DevOps organization name.
Replace {project} with your Azure DevOps project name.
Replace {feedId} with your Feed ID which is 30ed9892-ac99-4342-9647-3afea3dc4ef5 from your provided vstsFeed ID.
Replace username with your Azure DevOps username.
Replace pat_token with your Personal Access Token (PAT).

You can create a PAT by following these steps:
1.Sign in to your organization in Azure DevOps.
2.From your home page, open your user settings, and then select Personal access tokens.
3.Choose + New Token.
4.Name your token, select the organization where you're creating the token, and then choose a lifespan for your token.
6.Select the scopes for this token to authorize for your specific tasks. For this task, you can select "Packaging (read)".
When you're done, make sure to copy the token. You'll use this token as your password.

Please note that the response from the curl command is in JSON format. The project name and feed name can be extracted from the response. The response will look something like this:

`{  
  "id": "30ed9892-ac99-4342-9647-3afea3dc4ef5",  
  "name": "Your Feed Name",  
  "fullyQualifiedName": "Your Project Name/Your Feed Name",  
  ...  
}`  
 
You can extract the project and feed name by using a tool like jq:
`curl -u username:pat_token https://feeds.dev.azure.com/{organization}/{project}/_apis/packaging/feeds/{feedId}?api-version=6.1-preview.1 | jq -r '.name, .fullyQualifiedName'  
`
 
This will print out the feed name and fully qualified name (which includes the project name) to the console.

Please replace the placeholders with your actual values.

Example : 
curl -u username:pat_token https://feeds.dev.azure.com/fsdi/bb377ee2-33c8-4866-a55d-cbb0f72346e2/_apis/packaging/feeds/30ed9892-ac99-4342-9647-3afea3dc4ef5?api-version=6.1-preview.1  | jq -r '.name, .fullyQualifiedName' 

GET https://feeds.dev.azure.com/fsdi/bb377ee2-33c8-4866-a55d-cbb0f72346e2/_apis/packaging/feeds?api-version=7.2-preview.1

curl -u ardeshir_sepahsalar:4l5pgaiybqwbk3x5lxweicsubormifxnuefad5riot4csjo6bkqq https://feeds.dev.azure.com/fsdi/Unity/_apis/packaging/feeds?api-version=7.2-preview.1 | jq -r '.name, .fullyQualifiedName' 

