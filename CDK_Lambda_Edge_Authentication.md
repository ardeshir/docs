# CDK Lambda Edge Authentication 

#### Step 1: Set Up the S3 Bucket

1. Create an S3 Bucket
	- Go to the S3 console and create a new bucket.
	- Note the bucket name; you will need it later.
2. Configure Bucket Policy
	- Ensure the S3 bucket is not publicly accessible.
	- Add a bucket policy to allow access only from the CloudFront distribution (you will add this after creating the CloudFront distribution).

#### Step 2: Create the Lambda@Edge Function
 
- Write the Lambda Function
- Create a Lambda function that performs Basic Authentication.

```javascript 
exports.handler = async (event) => {  
    const authString = 'Basic ' + Buffer.from('username:password').toString('base64');  
      
    const request = event.Records[0].cf.request;  
    const headers = request.headers;  
  
    if (typeof headers.authorization === 'undefined' || headers.authorization[0].value !== authString) {  
        return {  
            status: '401',  
            statusDescription: 'Unauthorized',  
            headers: {  
                'www-authenticate': [{ key: 'WWW-Authenticate', value: 'Basic' }],  
                'content-type': [{ key: 'Content-Type', value: 'text/plain' }],  
            },  
            body: 'Unauthorized',  
        };  
    }  
  
    return request;  
};  
``` 
2. Deploy the Lambda Function

Lambda@Edge functions need to be deployed in the us-east-1 region (N. Virginia).
Create the Lambda function using the AWS Management Console or CLI.
#### Step 3: Configure CloudFront
 
1. Create a CloudFront Distribution
- Set up a CloudFront distribution with the S3 bucket as the origin.
- Add a behavior to use the Lambda function on the viewer request.
- Attach the Lambda Function to CloudFront
2. Go to the CloudFront distribution settings.
- In the "Behaviors" tab, attach the Lambda function to the "Viewer Request" event.

#### Step 4: Restrict S3 Bucket Access
 
- Add Bucket Policy
- Modify the S3 bucket policy to allow access only from the CloudFront distribution's origin access identity (OAI).
```json
{  
  "Version": "2012-10-17",  
  "Statement": [  
    {  
      "Effect": "Allow",  
      "Principal": {  
        "AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity E3EXAMPLE"  
      },  
      "Action": "s3:GetObject",  
      "Resource": "arn:aws:s3:::your-bucket-name/*"  
    }  
  ]  
} 
```

#### Step 1: Set Up Your CDK Project

1. Install AWS CDK
	- Ensure you have AWS CDK installed. If not, install it using npm.

` npm install -g aws-cdk`  
 
2. Initialize a New CDK Project
	- Create a new CDK project in Python.
```bash	
mkdir cdk_lambda_edge  
cd cdk_lambda_edge  
cdk init app --language python  
```
 
3. Install Required Libraries
	- Install the required libraries for S3, Lambda, and CloudFront.

` pip install aws-cdk-lib aws-cdk.aws_s3 aws-cdk.aws_lambda aws-cdk.aws_cloudfront `  
 

##### Step 2: Define the CDK Stack

	- Create the Stack in cdk_lambda_edge/cdk_lambda_edge_stack.py

```python 
from aws_cdk import (  
    Stack,  
    aws_s3 as s3,  
    aws_lambda as _lambda,  
    aws_cloudfront as cloudfront,  
    aws_cloudfront_origins as origins,  
    aws_iam as iam,  
)  
from constructs import Construct  
  
class CdkLambdaEdgeStack(Stack):  
  
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:  
        super().__init__(scope, construct_id, **kwargs)  
  
        # Create the S3 bucket  
        bucket = s3.Bucket(self, "LambdaEdgeAuth", versioned=True)  
  
        # Define the Lambda function  
        lambda_function = _lambda.Function(  
            self, "AuthLambdaEdgeFunction",  
            runtime=_lambda.Runtime.NODEJS_18_X,  
            handler="index.handler",  
            code=_lambda.Code.from_asset("lambda")  
        )  
  
        # Create an Origin Access Identity (OAI)  
        oai = cloudfront.OriginAccessIdentity(self, "MyOAI")  
  
        # Create a CloudFront distribution  
        distribution = cloudfront.Distribution(  
            self, "AuthLambdaDistribution",  
            default_behavior=cloudfront.BehaviorOptions(  
                origin=origins.S3Origin(bucket, origin_access_identity=oai),  
                edge_lambdas=[  
                    cloudfront.EdgeLambda(  
                        function_version=lambda_function.current_version,  
                        event_type=cloudfront.LambdaEdgeEventType.VIEWER_REQUEST  
                    )  
                ]  
            )  
        )  
  
        # Add bucket policy to restrict access to CloudFront  
        bucket.add_to_resource_policy(iam.PolicyStatement(  
            actions=["s3:GetObject"],  
            resources=[bucket.arn_for_objects("*")],  
            principals=[iam.ArnPrincipal(  
                f"arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity {oai.origin_access_identity_id}"  
            )]  
        ))  
  
```  
 
2. Create the Lambda Function Code
	- Create a directory named lambda in the root of your project.
	- Create a file named index.js inside the lambda directory.

```javascript 
exports.handler = async (event) => {  
    const authString = 'Basic ' + Buffer.from('username:password').toString('base64');  
      
    const request = event.Records[0].cf.request;  
    const headers = request.headers;  
  
    if (typeof headers.authorization === 'undefined' || headers.authorization[0].value !== authString) {  
        return {  
            status: '401',  
            statusDescription: 'Unauthorized',  
            headers: {  
                'www-authenticate': [{ key: 'WWW-Authenticate', value: 'Basic' }],  
                'content-type': [{ key: 'Content-Type', value: 'text/plain' }],  
            },  
            body: 'Unauthorized',  
        };  
    }  
  
    return request;  
};  
``` 
#### Step 3: Deploy the Stack
 

1. Bootstrap the CDK Environment
	- Before deploying the stack, you need to bootstrap your CDK environment. This step sets up the necessary resources for CDK to perform deployments.

` cdk bootstrap ` 
 
2. Deploy the Stack

	- Once the environment is bootstrapped, deploy the stack.

` cdk deploy  `
During the deployment process, CDK will create the S3 bucket, the Lambda@Edge function, and the CloudFront distribution as defined in your stack. It will also apply the necessary bucket policy to ensure that the S3 bucket can only be accessed via the CloudFront distribution.


#### Full Project Structure
 
- Here is the final project structure:

```text 
cdk_lambda_edge/  
├── cdk.out/  
├── lambda/  
│   └── index.js  
├── cdk_lambda_edge/  
│   ├── __init__.py  
│   └── cdk_lambda_edge_stack.py  
├── app.py  
├── cdk.json  
├── requirements.txt  
└── README.md  
``` 

#### Full Example Code
 
` app.py `

```bash
#!/usr/bin/env python3  
import aws_cdk as cdk  
from cdk_lambda_edge.cdk_lambda_edge_stack import CdkLambdaEdgeStack  
  
app = cdk.App()  
CdkLambdaEdgeStack(app, "CdkLambdaEdgeStack")  
app.synth()  
``` 

` cdk_lambda_edge/cdk_lambda_edge_stack.py `

```python 
from aws_cdk import (  
    Stack,  
    aws_s3 as s3,  
    aws_lambda as _lambda,  
    aws_cloudfront as cloudfront,  
    aws_cloudfront_origins as origins,  
    aws_iam as iam,  
)  
from constructs import Construct  
  
class CdkLambdaEdgeStack(Stack):  
  
    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:  
        super().__init__(scope, construct_id, **kwargs)  
  
        # Create the S3 bucket  
        bucket = s3.Bucket(self, "LambdaEdgeAuth", versioned=True)  
  
        # Define the Lambda function  
        lambda_function = _lambda.Function(  
            self, "AuthLambdaEdgeFunction",  
            runtime=_lambda.Runtime.NODEJS_18_X,  
            handler="index.handler",  
            code=_lambda.Code.from_asset("lambda")  
        )  
  
        # Create an Origin Access Identity (OAI)  
        oai = cloudfront.OriginAccessIdentity(self, "MyOAI")  
  
        # Create a CloudFront distribution  
        distribution = cloudfront.Distribution(  
            self, "AuthLambdaDistribution",  
            default_behavior=cloudfront.BehaviorOptions(  
                origin=origins.S3Origin(bucket, origin_access_identity=oai),  
                edge_lambdas=[  
                    cloudfront.EdgeLambda(  
                        function_version=lambda_function.current_version,  
                        event_type=cloudfront.LambdaEdgeEventType.VIEWER_REQUEST  
                    )  
                ]  
            )  
        )  
  
        # Add bucket policy to restrict access to CloudFront  
        bucket.add_to_resource_policy(iam.PolicyStatement(  
            actions=["s3:GetObject"],  
            resources=[bucket.arn_for_objects("*")],  
            principals=[iam.ArnPrincipal(  
                f"arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity {oai.origin_access_identity_id}"  
            )]  
        ))  
   
```
#### Verify the Deployment

Check the CloudFront Distribution
After the stack is deployed, go to the AWS Management Console and navigate to the CloudFront service.
Ensure that your CloudFront distribution is listed and active.
Test the Authentication
Use a web browser or a tool like curl to test accessing the S3 content through the CloudFront distribution.
You should be prompted for a username and password. Use the credentials you specified in the Lambda function.
- Check with 
` curl -u username:password https://<your-cloudfront-domain>/<your-s3-object>  `

