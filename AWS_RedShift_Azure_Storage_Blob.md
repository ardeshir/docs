# AWS RedShift UNLOAD to Azure Storage Blob 

Unloading data from AWS RedShift to Azure Blob Storage without using VPC peering, you can follow these steps. We'll use AWS services such as AWS Lambda and AWS Glue to automate the process and ensure the data remains in sync.

#### Step 1: Configure Azure Storage Account
 
1. Create an Azure Storage Account:
    - Go to the Azure portal.
    - Click on "Create a resource" > "Storage" > "Storage account".
    - Fill in the required information and create the storage account.
2. Create a Blob Container:
    - Navigate to your storage account.
    - Under "Data storage", click "Containers".
    - Click "+ Container" to create a new container where you will store your data.
#### Step 2: Set Up AWS RedShift
 

1. Create an AWS RedShift Cluster:
    - Sign in to the AWS Management Console.
    - Navigate to the RedShift service.
    - Click "Create cluster" and follow the prompts to configure your cluster.
2. Configure Security Groups:
    - Ensure that the RedShift cluster is within a security group that allows outbound traffic to the internet.

#### Step 3: Unload Data from RedShift to S3

1. Create an S3 Bucket:
    - Navigate to the S3 service in the AWS Management Console.
    - Create a new bucket where you will temporarily store the data unloaded from RedShift.
2. Unload Data from RedShift to S3:
    - Use the UNLOAD command in RedShift to export data to the S3 bucket.
    - Example SQL:

```sql
UNLOAD ('SELECT * FROM your_table')  
TO 's3://your-s3-bucket/prefix_'  
IAM_ROLE 'arn:aws:iam::account-id:role/yourRedshiftRole'  
ALLOWOVERWRITE  
PARALLEL OFF;  
```

#### Step 4: Transfer Data from S3 to Azure Blob Storage
 

1. Set Up AWS Lambda:
    - Create an AWS Lambda function that triggers on S3 ObjectCreated events.
    - This function will copy the newly unloaded data from the S3 bucket to Azure Blob Storage.
2. Configure Lambda Permissions:
    - Ensure the Lambda function has the necessary permissions to read from the S3 bucket and write to Azure Blob Storage.
3. Install Azure SDK in Lambda:
    - Use the AWS Lambda console to add the Azure Storage Blob SDK to your Lambda function.

***Example Lambda function code in Python:***

```python
import boto3  
from azure.storage.blob import BlobServiceClient  

s3 = boto3.client('s3')  

def lambda_handler(event, context):  
    for record in event['Records']:  
        bucket = record['s3']['bucket']['name']  
        key = record['s3']['object']['key']  

        # Download the file from S3  
        download_path = '/tmp/{}'.format(key)  
        s3.download_file(bucket, key, download_path)  

        # Upload the file to Azure Blob Storage  
        blob_service_client = BlobServiceClient.from_connection_string('your_connection_string')  
        blob_client = blob_service_client.get_blob_client(container='your_container', blob=key)  

        with open(download_path, 'rb') as data:  
            blob_client.upload_blob(data)  
``` 

#### Step 5: Automate the Process
 
1. AWS CloudWatch Events:
    - Set up a CloudWatch Event that triggers the UNLOAD command in RedShift on a schedule (e.g., every hour).
2. AWS Lambda Trigger:
    - Ensure the Lambda function is configured to trigger on the S3 ObjectCreated event.


