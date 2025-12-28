##### How to build a proper Monitoring Solutions with Application Insights & LogAnalytics

How do I configure logging for AzureWebApp1-38761621 to meet the following requirements:

1 - Collect monitoring data by using Application Insights. The data must be logged to LogAnalytics1.
2- Ensure that logging for the .NET core Snapshot Debugger is disabled.
3- Enable file and configuration change tracking for AzureWebApp1-38761621.
4- Ensure that the HTTP logs for AzureWebApp1-38761621 are sent to LogAnalytics1.
5- Ensure that the SQL Insights data for the Azure SQL database used by the web app is sent to LogAnalytics1.

##### Following these steps : 

1. Collect monitoring data by using Application Insights. The data must be logged to LogAnalytics1.
   
   You can collect monitoring data using Application Insights and log them to Log Analytics by linking Application Insights with Log Analytics workspace. Here are the steps:
   1.1 Navigate to your Application Insights resource.
   1.2 On the left pane, under "Configure", click on "Workspace-based resource mode"
   1.3 Click on "Select workspace" and choose your workspace "LogAnalytics1"
   1.4 Click on "Apply"
   
   Source: [Azure Documentation - Linking Application Insights and Log Analytics](https://docs.microsoft.com/en-us/azure/azure-monitor/app/enable-workbook-powerbi)

2. Ensure that logging for the .NET core Snapshot Debugger is disabled.
   
   You can disable Snapshot Debugger as follows:
   2.1 In your Azure portal, go to the Application Insights resource connected with the Azure Web App.
   2.2 Navigate to the "Performance" tab. 
   2.3 You will see "Snapshot Debugger" setting, toggle it OFF to disable it.
   
   Source: [Azure Documentation - Snapshot Debugger](https://docs.microsoft.com/en-us/azure/azure-monitor/app/snapshot-debugger)

3. Enable file and configuration change tracking for AzureWebApp1-38761621.
   
   You can use Azure Automation to enable file and configuration change tracking. Here are the steps:
   3.1 Navigate to your Azure Automation account.
   3.2 On the left pane, under "Configuration Management", click on "Change tracking and Inventory".
   3.3 Click on “+ Add Azure VMs” or “+ Add non-Azure machines”.
   3.4 Follow the wizard to add the resources you wish to track.
   
   Source: [Azure Documentation - Track Changes with Azure Automation](https://docs.microsoft.com/en-us/azure/automation/change-tracking)
   
4. Ensure that the HTTP logs for AzureWebApp1-38761621 are sent to LogAnalytics1.
   
   Azure Web Apps support two types of logging, Application Logging and Web Server Logging. To send HTTP Logs to Log Analytics:
   4.1 From the Azure portal, locate the App Service "AzureWebApp1-38761621".
   4.2 Under "Monitoring", select "App Service logs" and enable "Detailed error messages" and "Failed request tracing".
   4.3 Under "Diagnostic settings", click on "+ Add diagnostic setting", give it a name, choose "Sending to Log Analytics" option and pick your "LogAnalytics1" workspace from the dropdown menu.
   4.4 Check "HTTP Logs", and then click "Save".
   
   Source: [Azure Documentation - Enable diagnostics logging for apps in Azure App Service](https://docs.microsoft.com/en-us/azure/app-service/troubleshoot-diagnostic-logs)

5. Ensure that the SQL Insights data for the Azure SQL database used by the web app is sent to LogAnalytics1.
   
   You can enable Azure SQL insights data by performing the following steps:
   5.1 Navigate to the SQL database 
   5.2 Select "Diagnostic settings".
   5.3 Click on "+ Add diagnostic setting", give it a name, and pick your "LogAnalytics1" workspace from the dropdown menu.
   5.4 Check "SQLInsights" and click "Save".
   
   Source: [Azure Documentation - Monitor Azure SQL Database using Azure Log Analytics](https://docs.microsoft.com/en-us/azure/azure-monitor/insights/azure-sql)

