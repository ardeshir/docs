# AWS CDK Deployment of Redshift Lambda Sync 

To set up the AWS infrastructure using AWS CDK (Cloud Development Kit) for deploying the Lambda function that transfers data from S3 to Azure Blob Storage, follow the steps below. This includes creating the IAM role, the Lambda function, and the necessary permissions.

#### Step 1: Set Up AWS CDK

*** Install AWS CDK ***

`npm install -g aws-cdk`  
 
2. Initialize a New CDK Project:

```bash
mkdir redshift-to-azure  
cd redshift-to-azure  
cdk init app --language python  
```

3. Set Up a Virtual Environment:

```bash
python3 -m venv .env  
source .env/bin/activate  
pip install -r requirements.txt  
``` 

4. Install CDK Libraries:

```bash
pip install aws-cdk.aws-lambda aws-cdk.aws-s3 aws-cdk.aws-iam aws-cdk.aws-events aws-cdk.aws-events-targets  
```

##### Step 2: Define the CDK Stack
 

    - Create a new file lambda_s3_to_blob.py in the redshift_to_azure directory and add the following code:

```python 
from aws_cdk import (  
    core,  
    aws_lambda as _lambda,  
    aws_s3 as s3,  
    aws_iam as iam,  
    aws_events as events,  
    aws_events_targets as targets,  
)  
import os  

class RedshiftToAzureStack(core.Stack):  

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:  
        super().__init__(scope, id, **kwargs)  

        # Create an S3 bucket  
        bucket = s3.Bucket(self, "RedshiftUnloadBucket")  

        # Define the IAM role for Lambda  
        lambda_role = iam.Role(self, "LambdaExecutionRole",  
            assumed_by=iam.ServicePrincipal("lambda.amazonaws.com"),  
            managed_policies=[  
                iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AWSLambdaBasicExecutionRole"),  
                iam.ManagedPolicy.from_aws_managed_policy_name("AmazonS3FullAccess")  
            ]  
        )  

        # Lambda function code  
        with open("lambda_function.py", encoding="utf8") as fp:  
            lambda_code = fp.read()  

        # Create the Lambda function  
        lambda_function = _lambda.Function(self, "S3ToAzureLambda",  
            runtime=_lambda.Runtime.PYTHON_3_8,  
            handler="index.lambda_handler",  
            code=_lambda.Code.from_inline(lambda_code),  
            role=lambda_role,  
            environment={  
                'AZURE_STORAGE_CONNECTION_STRING': os.getenv('AZURE_STORAGE_CONNECTION_STRING'),  
                'AZURE_STORAGE_CONTAINER_NAME': os.getenv('AZURE_STORAGE_CONTAINER_NAME')  
            }  
        )  

        # Grant S3 read permissions to the Lambda function  
        bucket.grant_read(lambda_function)  

        # S3 event source for Lambda  
        lambda_function.add_event_source(  
            s3n.S3EventSource(bucket, events=["s3:ObjectCreated:*"])  
        )  

        # Create a CloudWatch rule to trigger the Lambda function periodically (e.g., every hour)  
        rule = events.Rule(self, "ScheduleRule",  
            schedule=events.Schedule.rate(core.Duration.hours(1)),  
        )  

        rule.add_target(targets.LambdaFunction(lambda_function))  
``` 
#### Step 3: Define the Lambda Function Code
 
2. Create the Lambda Function Code:

    - Create a new file lambda_function.py in the root directory and add the following code:

```python
import boto3  
from azure.storage.blob import BlobServiceClient  
import os  

s3 = boto3.client('s3')  

def lambda_handler(event, context):  
    for record in event['Records']:  
        bucket = record['s3']['bucket']['name']  
        key = record['s3']['object']['key']  

        # Download the file from S3  
        download_path = '/tmp/{}'.format(key)  
        s3.download_file(bucket, key, download_path)  

        # Upload the file to Azure Blob Storage  
        connection_string = os.getenv('AZURE_STORAGE_CONNECTION_STRING')  
        container_name = os.getenv('AZURE_STORAGE_CONTAINER_NAME')  
        blob_service_client = BlobServiceClient.from_connection_string(connection_string)  
        blob_client = blob_service_client.get_blob_client(container=container_name, blob=key)  

        with open(download_path, 'rb') as data:  
            blob_client.upload_blob(data)  
``` 

#### Step 4: Deploy the CDK Stack
 

1. Update Environment Variables:
    - Ensure that you set the environment variables for the Azure Storage connection string and container name in your terminal before deploying:

```bash
export AZURE_STORAGE_CONNECTION_STRING="you_azure_storage_connection_string"  
export AZURE_STORAGE_CONTAINER_NAME="your_container_name"  
```

2. Deploy the CDK Stack:

- Bootstrap your AWS environment if you haven't done it before:


` cdk bootstrap `

- Deploy the stack:


` cdk deploy ` 
 

##### Step 5: Verify the Deployment
 

Check AWS Console:
Verify that the S3 bucket, Lambda function, and CloudWatch rule are created in the AWS Management Console.
Test the Setup:
Upload a test file to the S3 bucket and check if it is transferred to the Azure Blob Storage.

#### Summary
 
This solution uses AWS CDK to create the necessary infrastructure to automate the process of unloading data from AWS RedShift to an S3 bucket and then transferring that data to Azure Blob Storage using a Lambda function. The Lambda function is triggered by S3 ObjectCreated events and uses the Azure Blob Storage SDK to upload the files to Azure Blob Storage.

##### Additional Resources
 
- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/v2/guide/home.html)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [Azure Storage Blob SDK for Python](https://learn.microsoft.com/en-us/python/api/overview/azure/storage-blob-readme?view=azure-python)

