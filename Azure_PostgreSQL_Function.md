# Connecting to Azure PostgreSQL with Azure Functions

- I want to create a DB role for fsdi-Unity-Developer group to be able to query database. I'm not a PostgreSQL expert, so testing this out, I do have a server pgsql-fsdi-unity-dev with database cnc-cns-data, what are the steps needed to connect a CSharp client application ?  show all the requirements to building Azure PostgreSQL db, table and connecting with RBACP with a AAD Group fsdi-Unity-Develper? 

To create an Azure PostgreSQL database, set up a table, and connect a C# client application using RBAC with an AAD group, follow these steps:

#### Step 1: Create an Azure PostgreSQL Database
 

1. Log in to Azure Portal:
- Go to the Azure portal: https://portal.azure.com
2. Create a PostgreSQL server:
- Search for "Azure Database for PostgreSQL".
- Click "Add" to create a new PostgreSQL server.
- Fill in the necessary details like Subscription, Resource Group, Server Name, Data Source, Location, Version, etc.
- Set the administrator username and password.
- Configure the networking settings as necessary.
- Review and create the server.
3. Create a database:
- Go to your PostgreSQL server in the Azure portal.
- Under "Settings", click on "Databases".
- Click "Add Database".
- Fill in the database name (cnc-cns-data), and other details as required.
- Click "OK" to create the database.

#### Step 2: Configure Azure AD Authentication
 

1. Enable Azure AD authentication:
- Go to your PostgreSQL server in the Azure portal.
- Under "Settings", click on "Active Directory admin".
- Click "Set admin" and select an Azure AD group or user to be the admin.
- Click "Save".
2. Assign the AAD group to the database:
- Go to the Azure Active Directory service in the Azure portal.
- Search for and select the fsdi-Unity-Developer group.
- Note the Object ID of the group, as you will need it later.


#### Step 3: Connect and Configure PostgreSQL
 
- Install PostgreSQL client tools:
- Install psql (PostgreSQL command-line tool) on your local machine if you haven't already.

You can download it from the PostgreSQL website: https://www.postgresql.org/download/
Connect to the PostgreSQL server:
- Use the psql tool to connect to your PostgreSQL server:

```sql
psql "host=<your_server_name>.postgres.database.azure.com port=5432 dbname=postgres user=<admin_username>@<your_server_name> password=<admin_password> sslmode=require"  
```
 
3. Create a role for the Azure AD group:

- Once connected, create a role for the Azure AD group:

```sql 
CREATE ROLE fsdi_unity_developer;  
``` 
4. Grant privileges to the role:

- Grant the necessary privileges to the role:

```sql 
GRANT CONNECT ON DATABASE "cnc-cns-data" TO fsdi_unity_developer;  
``` 
5. Map the AAD group to the PostgreSQL role:

- Use the Object ID of the AAD group noted earlier:
```sql
CREATE ROLE "azure_ad_group" NOLOGIN;  
GRANT fsdi_unity_developer TO "azure_ad_group";  
``` 

##### Step 4: Create a Table in the Database
 

- Connect to the cnc-cns-data database:
Use the psql tool to connect to the cnc-cns-data database:

```bash
psql "host=<your_server_name>.postgres.database.azure.com port=5432 dbname=cnc-cns-data user=<admin_username>@<your_server_name> password=<admin_password> sslmode=require"  
```
 
2. Create a table:

- Create a sample table:
```sql 
CREATE TABLE sample_table (  
    id SERIAL PRIMARY KEY,  
    name VARCHAR(100),  
    value INT  
);  
``` 

Can you develop a CSharp Azure client Function Application that uses this setup, and is able to make queries to the PostgreSQL db  & table, with appropriate dotnet mackages to use to connect to the Server from Azure functions?


Below are the steps to develop a C# Azure Function that connects to the PostgreSQL database using the setup described.

#### Step 1: Create an Azure Function App
 

1. Create an Azure Function App in the Azure Portal:
- Go to the Azure portal: https://portal.azure.com
- Click "Create a resource" and search for "Function App".
- Click "Create" and fill in the necessary details (Subscription, Resource Group, Function App name, Runtime stack as .NET, etc.)
Review and create the Function App.

#### Step 2: Set up the Development Environment
 

1. Install .NET SDK:
- Ensure you have the .NET SDK installed. You can download it from: https://dotnet.microsoft.com/download
2. Install Azure Functions Core Tools:
- Install Azure Functions Core Tools to develop and test functions locally:

`npm install -g azure-functions-core-tools@3`  
 
3. Create a new Azure Functions project:

- Open a terminal or command prompt and create a new Functions project:

```bash
func init MyFunctionApp --dotnet  
cd MyFunctionApp  
func new --template "HttpTrigger" --name "QueryPostgreSqlFunction"  
``` 

####  Step 3: Add Required NuGet Packages
 

- Install Npgsql package:
Npgsql is an open-source .NET data provider for PostgreSQL:

- dotnet add package Npgsql  
 
2. Install Microsoft.Extensions.Configuration and other necessary packages:

These packages help manage configuration and secrets:

- dotnet add package Microsoft.Extensions.Configuration  
- dotnet add package Microsoft.Extensions.Configuration.Json  
- dotnet add package Microsoft.Extensions.Configuration.EnvironmentVariables  
 

#### Step 4: Implement the Azure Function
 

- Update the QueryPostgreSqlFunction.cs:
Replace the contents of QueryPostgreSqlFunction.cs with the following code:

```CSharp
using System;  
using System.IO;  
using System.Threading.Tasks;  
using Microsoft.AspNetCore.Mvc;  
using Microsoft.Azure.WebJobs;  
using Microsoft.Azure.WebJobs.Extensions.Http;  
using Microsoft.AspNetCore.Http;  
using Microsoft.Extensions.Logging;  
using Npgsql;  
using Microsoft.Extensions.Configuration;  

public static class QueryPostgreSqlFunction  
{  
    private static IConfiguration Configuration;  

    static QueryPostgreSqlFunction()  
    {  
        var builder = new ConfigurationBuilder()  
            .SetBasePath(Directory.GetCurrentDirectory())  
            .AddJsonFile("local.settings.json", optional: true, reloadOnChange: true)  
            .AddEnvironmentVariables();  
        Configuration = builder.Build();  
    }  

    [FunctionName("QueryPostgreSqlFunction")]  
    public static async Task<IActionResult> Run(  
        [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,  
        ILogger log)  
    {  
        log.LogInformation("C# HTTP trigger function processed a request.");  

        string connString = Configuration["PostgreSqlConnectionString"];  

        string query = "SELECT id, name, value FROM sample_table LIMIT 10";  
        var result = new System.Text.StringBuilder();  

        await using (var conn = new NpgsqlConnection(connString))  
        {  
            await conn.OpenAsync();  
            await using (var cmd = new NpgsqlCommand(query, conn))  
            await using (var reader = await cmd.ExecuteReaderAsync())  
            {  
                while (await reader.ReadAsync())  
                {  
                    result.AppendLine($"{reader.GetInt32(0)}, {reader.GetString(1)}, {reader.GetInt32(2)}");  
                }  
            }  
        }  

        return new OkObjectResult(result.ToString());  
    }  
}  
```


#### Step 4: Implement the Azure Function (continued)
 
2. Update local.settings.json:

Add the connection string to local.settings.json for local development:

{  
  "IsEncrypted": false,  
  "Values": {  
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",  
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",  
    "PostgreSqlConnectionString": "Host=<your_server_name>.postgres.database.azure.com;Username=<aad_user>@<your_server_name>;Password=<aad_user_password>;Database=cnc-cns-data;SslMode=Require;Trust Server Certificate=true"  
  }  
}  
Make sure to replace placeholders (<your_server_name>, <aad_user>, and <aad_user_password>) with actual values.
Step 5: Deploy the Azure Function App
 

Login to Azure:
Use the Azure CLI to log in to your Azure account:

az login  
 
2. Deploy the Function App:

Navigate to the project directory and deploy the function app to Azure:

func azure functionapp publish <your_function_app_name>  
 
3. Configure the Connection String in Azure:

- Go to your Function App in the Azure portal.
- Under "Settings", click on "Configuration".
- Click "New application setting" and add the connection string as follows:
- - Name: PostgreSqlConnectionString
- - Value: Host=<your_server_name>.postgres.database.azure.com;Username=<aad_user>@<your_server_name>;Password=<aad_user_password>;Database=cnc-cns-data;SslMode=Require;Trust Server Certificate=true
Click "OK" and then "Save" to apply the settings.


####  Step 6: Test the Azure Function
 

1. Invoke the Function:
- You can test the function using an HTTP client like curl, Postman, or directly from a browser.
- The URL format will be: https://<your_function_app_name>.azurewebsites.net/api/QueryPostgreSqlFunction
- Example using curl:
```bash
curl -X GET "https://<your_function_app_name>.azurewebsites.net/api/QueryPostgreSqlFunction"  
```
 
2. Check the Logs:

- You can monitor the logs in the Azure portal under "Monitor" for the function app to see the execution details and any errors.
#### Step 7: Secure the Function
 

- Set Function Authorization Level:
- Ensure the authorization level is set to Function in the QueryPostgreSqlFunction attribute:

```CSharp
[FunctionName("QueryPostgreSqlFunction")]  
public static async Task<IActionResult> Run(  
    [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req,  
    ILogger log)  
``` 
2. Generate Function Key:

- Go to the Azure portal, navigate to your Function App, and under "Functions", select your function.
- Click on "Manage" and generate a new function key.
- Use this key when making HTTP requests to the function by adding it as a query parameter:
```bash 
curl -X GET "https://<your_function_app_name>.azurewebsites.net/api/QueryPostgreSqlFunction?code=<your_function_key>"  
``` 
By following these steps, you have created an Azure Function that connects to a PostgreSQL database using Azure Active Directory authentication, queries the database, and returns the results. This setup ensures secure and efficient communication between your C# application and the PostgreSQL database hosted on Azure.
