#### You need to collect telemetry data from VM1 by using the Azure Monitor Agent and log the data to LogAnalytics1. The solution must meet the following requirements:

1- Create a data collection rule (DCR) that logs the following data:
IIS logs,
2- Audit failure events from the Security event log,
3- Critical and error events from the System event log, and
4- Critical and error events from the Application event log.
Enable VM insights.
5- You also need to monitor HTTP availability to the public IP address of VM1 from the public IP address of Linux-VM. The data must be logged to LogAnalytics1.

### Solution: Step 1: Install Azure Monitor Agent on VM1
Follow this guide from Microsoft: https://docs.microsoft.com/en-us/azure/azure-monitor/

Step 2: Create Data Collection Rule
You'll need to create a Data Collection Rule (DCR). Please follow this guide from Microsoft: https://docs.microsoft.com/en-us/azure/azure-monitor/agents/create-data-collection-rule 

When you're setting up the DCR try to include these items and their respective categories:

- IIS Logs
- System Event Logs: Critical and Error events 
- Application Event Logs: Critical and Error events
- Security Event Logs: Audit Failure events

Step 3: Enable VM Insights
Use Microsoft's guide on enabling VM insights: https://docs.microsoft.com/en-us/azure/azure-monitor/insights/vminsights-enable-overview

Step 4: Monitor HTTP availability
For HTTP availability, you need to create a multi-step web test over HTTP/S which you can see in the following guide: https://docs.microsoft.com/en-us/azure/azure-monitor/app/monitor-web-app-availability#create-a-multi-step-web-test 

There currently isn't a direct way to monitor HTTP availability between two VMs publicly. What you can do is write a script in Linux VM to ping VM1 and send the log to LogAnalytics1.

Remember that this is a versatile process and might be subject to change depending on your specifications and VM configs.
