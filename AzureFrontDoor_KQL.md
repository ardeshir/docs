# Q: Help me get more information from Azure FrontDoor Premium query to find out what the path for and where it's coming from?  This is what i have to work with, but I need to know more about client and path ?  
  
  
AzureDiagnostics  
| where requestUri_s contains_cs  "api.formulationcloud.com:443/api/import"   
and httpStatusCode_d  >= 500  
| project when=TimeGenerated, url=requestUri_s, status = httpStatusCode_d, timeTaken_s 


# A: 

To further refine your query and get more information about the client and path, you can use the clientIp_s field to get the IP address of the client, and the url or requestUri_s field to get the path.

Here's how you can modify your query:
AzureDiagnostics  
| where requestUri_s contains_cs "api.formulationcloud.com:443/api/import"   
and httpStatusCode_d >= 500  
| project when=TimeGenerated,  url=requestUri_s, status=httpStatusCode_d,timeTaken_s, clientIp=clientIp_s, path=parse_url(requestUri_s).Path  

In this query, the clientIp_s field will give you the IP address of the client making the request, and the parse_url(requestUri_s).Path will give you the path of the request.

Also, please note that the fields available for you might depend on the specific schema of your AzureDiagnostics logs.

You can find more information about the schema of AzureDiagnostics logs and the fields available to you in the official Microsoft Azure documentation:

https://docs.microsoft.com/en-us/azure/azure-monitor/reference/tables/azurediagnostics

You can also get more information about the parse_url() function in the Kusto Query Language (KQL) from the Azure Data Explorer documentation:

https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/parseurlfunction
