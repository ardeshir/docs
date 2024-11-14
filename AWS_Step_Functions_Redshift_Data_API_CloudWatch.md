# AWS Step Functions Workflow for Redshift Data API triggered from CloudWatch

Using AWS Step Functions to run the UNLOAD command on RedShift using the RedShift Data API is an efficient approach. This way, you avoid using Lambda for long-running queries and directly manage the workflow with Step Functions triggered by CloudWatch Events.

#### Step 1: Configure AWS RedShift Data API
 

1. Enable the RedShift Data API:
	- Ensure that your RedShift cluster is using an IAM role that has the necessary permissions to use the Data API.
	- Create an IAM Role for Step Functions:
2. This role will need permissions to execute the RedShift Data API commands.
	- Example IAM Policy for RedShift Data API:
```json
{  
  "Version": "2012-10-17",  
  "Statement": [  
    {  
      "Effect": "Allow",  
      "Action": [  
        "redshift-data:ExecuteStatement",  
        "redshift-data:DescribeStatement",  
        "redshift-data:GetStatementResult"  
      ],  
      "Resource": "*"  
    }  
  ]  
}  
``` 

#### Step 2: Create a Step Functions Workflow
 

1. Define the Step Functions Workflow:
	- Create a state machine definition to run the UNLOAD command and check the status until completion.
	- Example state machine definition in JSON:
```json 
{  
  "Comment": "StateMachine to UNLOAD data from RedShift",  
  "StartAt": "StartUnload",  
  "States": {  
    "StartUnload": {  
      "Type": "Task",  
      "Resource": "arn:aws:states:::aws-sdk:redshiftdata:executeStatement",  
      "Parameters": {  
        "ClusterIdentifier": "your-cluster-identifier",  
        "Database": "your-database-name",  
        "DbUser": "your-db-user",  
        "Sql": "UNLOAD ('SELECT * FROM your_table') TO 's3://your-s3-bucket/prefix_' IAM_ROLE 'arn:aws:iam::account-id:role/yourRedshiftRole' ALLOWOVERWRITE PARALLEL OFF;",  
        "StatementName": "StartUnload"  
      },  
      "Next": "CheckUnloadStatus"  
    },  
    "CheckUnloadStatus": {  
      "Type": "Wait",  
      "Seconds": 30,  
      "Next": "GetUnloadStatus"  
    },  
    "GetUnloadStatus": {  
      "Type": "Task",  
      "Resource": "arn:aws:states:::aws-sdk:redshiftdata:describeStatement",  
      "Parameters": {  
        "Id.$": "$.StartUnload.Id"  
      },  
      "Next": "IsUnloadComplete"  
    },  
    "IsUnloadComplete": {  
      "Type": "Choice",  
      "Choices": [  
        {  
          "Variable": "$.Status",  
          "StringEquals": "FINISHED",  
          "Next": "Success"  
        },  
        {  
          "Variable": "$.Status",  
          "StringEquals": "FAILED",  
          "Next": "Fail"  
        }  
      ],  
      "Default": "CheckUnloadStatus"  
    },  
    "Success": {  
      "Type": "Succeed"  
    },  
    "Fail": {  
      "Type": "Fail",  
      "Error": "UNLOADFailed",  
      "Cause": "The UNLOAD command failed."  
    }  
  }  
}  
``` 

#### Step 2: Create a Step Functions Workflow (continued)
 
1. Deploy the State Machine Using CDK:

	- Create a new file redshift_unload_step_function_stack.py in your CDK project and add the following code:

```python 
from aws_cdk import (  
    core,  
    aws_stepfunctions as sfn,  
    aws_stepfunctions_tasks as tasks,  
    aws_iam as iam,  
    aws_events as events,  
    aws_events_targets as targets,  
)  

class RedshiftUnloadStepFunctionStack(core.Stack):  

    def __init__(self, scope: core.Construct, id: str, **kwargs) -> None:  
        super().__init__(scope, id, **kwargs)  

        # Define the IAM role for Step Functions  
        step_function_role = iam.Role(self, "StepFunctionRole",  
            assumed_by=iam.ServicePrincipal("states.amazonaws.com"),  
            managed_policies=[  
                iam.ManagedPolicy.from_aws_managed_policy_name("AmazonRedshiftDataFullAccess")  
            ]  
        )  

        # Define the Step Functions state machine definition  
        start_unload_task = tasks.CallAwsService(self, "StartUnload",  
            service="redshiftdata",  
            action="executeStatement",  
            parameters={  
                "ClusterIdentifier": "your-cluster-identifier",  
                "Database": "your-database-name",  
                "DbUser": "your-db-user",  
                "Sql": "UNLOAD ('SELECT * FROM your_table') TO 's3://your-s3-bucket/prefix_' IAM_ROLE 'arn:aws:iam::account-id:role/yourRedshiftRole' ALLOWOVERWRITE PARALLEL OFF;",  
                "StatementName": "StartUnload"  
            },  
            iam_resources=["*"],  
            result_path="$.StartUnload"  
        )  

        check_unload_status_task = sfn.Wait(self, "CheckUnloadStatus",  
            time=sfn.WaitTime.duration(core.Duration.seconds(30))  
        )  

        get_unload_status_task = tasks.CallAwsService(self, "GetUnloadStatus",  
            service="redshiftdata",  
            action="describeStatement",  
            parameters={  
                "Id.$": "$.StartUnload.Id"  
            },  
            iam_resources=["*"],  
            result_path="$.GetUnloadStatus"  
        )  

        is_unload_complete_choice = sfn.Choice(self, "IsUnloadComplete")  
        success_state = sfn.Succeed(self, "Success")  
        fail_state = sfn.Fail(self, "Fail",  
            error="UNLOADFailed",  
            cause="The UNLOAD command failed."  
        )  

        is_unload_complete_choice.when(  
            sfn.Condition.string_equals("$.GetUnloadStatus.Status", "FINISHED"),  
            success_state  
        ).when(  
            sfn.Condition.string_equals("$.GetUnloadStatus.Status", "FAILED"),  
            fail_state  
        ).otherwise(  
            check_unload_status_task.next(get_unload_status_task)  
        )  

        definition = start_unload_task.next(check_unload_status_task) \  
            .next(get_unload_status_task) \  
            .next(is_unload_complete_choice)  

        state_machine = sfn.StateMachine(self, "RedshiftUnloadStateMachine",  
            definition=definition,  
            role=step_function_role,  
            timeout=core.Duration.hours(1)  
        )  

        # Create a CloudWatch rule to trigger the state machine periodically (e.g., every hour)  
        rule = events.Rule(self, "ScheduleRule",  
            schedule=events.Schedule.rate(core.Duration.hours(1)),  
        )  

        rule.add_target(targets.SfnStateMachine(state_machine))  
``` 

#### Step 3: Deploy the CDK Stack
 
1. Update the app.py File:
	- Open the app.py file in your CDK project and instantiate the RedshiftUnloadStepFunctionStack class:

```python
# app.py  
from aws_cdk import core  
from redshift_unload_step_function_stack import RedshiftUnloadStepFunctionStack  

app = core.App()  
RedshiftUnloadStepFunctionStack(app, "RedshiftUnloadStepFunctionStack")  

app.synth() 
``` 
 
2. Deploy the CDK Stack:

	- Ensure you have set up the necessary environment variables for AWS credentials.

	- Bootstrap your AWS environment if you haven't done it before:


` cdk bootstrap `  

- Deploy the stack:


` cdk deploy `  
 

#### Summary
 
This solution uses AWS CDK to create a Step Functions workflow that runs the UNLOAD command on RedShift using the RedShift Data API. The workflow is triggered by a CloudWatch Event on a scheduled basis (e.g., every hour). The Step Functions state machine handles the execution and monitoring of the UNLOAD command, ensuring it completes successfully or fails gracefully.

##### Additional Resources
 

- [AWS CDK v2](https://docs.aws.amazon.com/cdk/v2/guide/home.html)
- [AWS Step Functions](https://docs.aws.amazon.com/step-functions/latest/dg/welcome.html)
- [AWS Redshift Data API](https://docs.aws.amazon.com/redshift/latest/mgmt/data-api.html)
