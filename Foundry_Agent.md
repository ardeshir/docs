# Foundry Agent
To use your created Connected Resource (SharePoint site) in a project with chat or agents to search your data in SharePoint, follow these steps:

### Ensure Prerequisites:

You should have a Microsoft 365 Copilot license.
Make sure you and the agent have at least the Azure AI User role, and that you have READ access to the SharePoint site.

Create or Configure an Agent:

- Navigate to the Azure AI Foundry portal.
- Either create a new agent or select an existing one.
- Add the SharePoint Tool:

In the agent's setup pane, scroll down to the "Knowledge" section and select "Add."

- Choose the SharePoint tool from the available options and follow the prompts to configure it.
- Connect the SharePoint Site:

Create a new connection by entering the site_url of your SharePoint site (e.g., https://microsoft.sharepoint.com/teams/<site_name>), or specify a folder if you prefer.

- Make sure to mark the connection as "secret" to protect your credentials.

### Implement Querying:

Once your agent is set up with the SharePoint tool, it will be able to send queries to SharePoint.
When a user sends a query, the agent determines if SharePoint should be leveraged and retrieves relevant documents from the site based on the user's permissions.

Generate Responses:

The agent will generate responses based on the retrieved information from SharePoint, leveraging the integration with the Microsoft 365 Copilot API for enhanced retrieval capabilities.