# AWS China Log Backup Strategy: Beijing to Ningxia

## Overview

This comprehensive strategy outlines how to backup EC2, Database, and VPC traffic flow logs from AWS China Beijing Region (cn-north-1) to AWS China Ningxia Region (cn-northwest-1).

## Key Considerations for AWS China Regions

- **Endpoints**: Use `amazonaws.com.cn` domain for all services
- **ARN Format**: Include `cn` in ARNs (e.g., `arn:aws-cn:s3:::bucket-name`)
- **Cross-Region Support**: Limited to between cn-north-1 and cn-northwest-1 only
- **Services**: Not all AWS services available; focus on supported services
- **Billing**: Priced in CNY, managed by Sinnet and NWCD

## Architecture Components

### Primary Services Used
1. **Amazon S3** - Cross-region log storage
2. **AWS Backup** - Centralized backup management
3. **Amazon CloudWatch Logs** - Log aggregation and streaming
4. **Amazon Kinesis Data Firehose** - Real-time log streaming
5. **VPC Flow Logs** - Network traffic logging
6. **Amazon RDS** - Database log publishing

---

## Strategy 1: VPC Flow Logs Backup

### Step 1: Create S3 Bucket in Ningxia (cn-northwest-1)

```bash
# Create S3 bucket in Ningxia region
aws s3api create-bucket \
  --bucket vpc-flow-logs-backup-ningxia \
  --region cn-northwest-1 \
  --create-bucket-configuration LocationConstraint=cn-northwest-1 \
  --endpoint-url https://s3.cn-northwest-1.amazonaws.com.cn
```

### Step 2: Create IAM Role for VPC Flow Logs

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**IAM Policy for Cross-Region S3 Access:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetBucketAcl",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws-cn:s3:::vpc-flow-logs-backup-ningxia",
        "arn:aws-cn:s3:::vpc-flow-logs-backup-ningxia/*"
      ]
    }
  ]
}
```

### Step 3: Configure VPC Flow Logs in Beijing

**Method A: Direct to S3 (Recommended)**

```bash
# Create VPC Flow Log directly to Ningxia S3
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxxxxxxx \
  --traffic-type ALL \
  --log-destination-type s3 \
  --log-destination arn:aws-cn:s3:::vpc-flow-logs-backup-ningxia/vpc-flow-logs/ \
  --deliver-logs-permission-arn arn:aws-cn:iam::ACCOUNT-ID:role/VPCFlowLogsRole \
  --region cn-north-1 \
  --endpoint-url https://ec2.cn-north-1.amazonaws.com.cn
```

**Method B: Via CloudWatch Logs + Kinesis Firehose**

1. Create CloudWatch Log Group in Beijing:
```bash
aws logs create-log-group \
  --log-group-name /aws/vpc/flowlogs \
  --region cn-north-1 \
  --endpoint-url https://logs.cn-north-1.amazonaws.com.cn
```

2. Create VPC Flow Log to CloudWatch:
```bash
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids vpc-xxxxxxxx \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/flowlogs \
  --deliver-logs-permission-arn arn:aws-cn:iam::ACCOUNT-ID:role/flowlogsRole \
  --region cn-north-1
```

### Step 4: Set Up Cross-Region Streaming with Kinesis Firehose

1. **Create Kinesis Data Firehose Delivery Stream in Beijing:**

```bash
aws firehose create-delivery-stream \
  --delivery-stream-name vpc-logs-to-ningxia \
  --delivery-stream-type DirectPut \
  --s3-destination-configuration \
    RoleARN=arn:aws-cn:iam::ACCOUNT-ID:role/firehose-delivery-role,\
    BucketARN=arn:aws-cn:s3:::vpc-flow-logs-backup-ningxia,\
    Prefix=vpc-flow-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/,\
    CompressionFormat=GZIP \
  --region cn-north-1 \
  --endpoint-url https://firehose.cn-north-1.amazonaws.com.cn
```

2. **Create CloudWatch Logs Subscription Filter:**

```bash
aws logs put-subscription-filter \
  --log-group-name /aws/vpc/flowlogs \
  --filter-name VPCFlowLogsToFirehose \
  --filter-pattern "" \
  --destination-arn arn:aws-cn:firehose:cn-north-1:ACCOUNT-ID:deliverystream/vpc-logs-to-ningxia \
  --region cn-north-1
```

---

## Strategy 2: EC2 Logs Backup

### Step 1: Configure CloudWatch Agent on EC2 Instances

**CloudWatch Agent Configuration:**

```json
{
  "agent": {
    "metrics_collection_interval": 300,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/system-logs",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/aws/ec2/application-logs",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
```

### Step 2: Create Cross-Region Log Backup Pipeline

1. **Create Kinesis Data Firehose for EC2 Logs:**

```bash
aws firehose create-delivery-stream \
  --delivery-stream-name ec2-logs-to-ningxia \
  --delivery-stream-type DirectPut \
  --s3-destination-configuration \
    RoleARN=arn:aws-cn:iam::ACCOUNT-ID:role/firehose-delivery-role,\
    BucketARN=arn:aws-cn:s3:::ec2-logs-backup-ningxia,\
    Prefix=ec2-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/,\
    CompressionFormat=GZIP,\
    BufferingHints={SizeInMBs=5,IntervalInSeconds=300} \
  --region cn-north-1
```

2. **Set Up Lambda Function for Log Processing (Optional):**

```python
import json
import boto3
import base64
import gzip

def lambda_handler(event, context):
    firehose = boto3.client('firehose', region_name='cn-north-1', 
                           endpoint_url='https://firehose.cn-north-1.amazonaws.com.cn')
    
    output = []
    for record in event['records']:
        # Decode and decompress CloudWatch Logs data
        payload = base64.b64decode(record['data'])
        data = json.loads(gzip.decompress(payload))
        
        # Process each log event
        for log_event in data['logEvents']:
            processed_record = {
                'recordId': record['recordId'],
                'result': 'Ok',
                'data': base64.b64encode(
                    json.dumps({
                        'timestamp': log_event['timestamp'],
                        'message': log_event['message'],
                        'logGroup': data['logGroup'],
                        'logStream': data['logStream'],
                        'instanceId': data['logStream']
                    }).encode('utf-8')
                ).decode('utf-8')
            }
            output.append(processed_record)
    
    return {'records': output}
```

### Step 3: Configure Automated Export to S3

**CloudWatch Logs Export Task (Scheduled via EventBridge):**

```bash
aws logs create-export-task \
  --log-group-name /aws/ec2/system-logs \
  --from 1640995200000 \
  --to 1641081600000 \
  --destination arn:aws-cn:s3:::ec2-logs-backup-ningxia \
  --destination-prefix ec2-logs/exported/ \
  --region cn-north-1
```

---

## Strategy 3: Database Logs Backup

### Step 1: Enable RDS Log Publishing to CloudWatch

**For MySQL/MariaDB:**

```bash
aws rds modify-db-instance \
  --db-instance-identifier mydb-instance \
  --cloudwatch-logs-export-configuration LogTypesToEnable=error,general,slow-query \
  --region cn-north-1 \
  --endpoint-url https://rds.cn-north-1.amazonaws.com.cn
```

**For PostgreSQL:**

```bash
aws rds modify-db-instance \
  --db-instance-identifier mydb-instance \
  --cloudwatch-logs-export-configuration LogTypesToEnable=postgresql \
  --region cn-north-1
```

### Step 2: Create RDS Log Backup Pipeline

1. **Create Dedicated S3 Bucket for Database Logs:**

```bash
aws s3api create-bucket \
  --bucket rds-logs-backup-ningxia \
  --region cn-northwest-1 \
  --create-bucket-configuration LocationConstraint=cn-northwest-1 \
  --endpoint-url https://s3.cn-northwest-1.amazonaws.com.cn
```

2. **Set Up Kinesis Firehose for Database Logs:**

```bash
aws firehose create-delivery-stream \
  --delivery-stream-name rds-logs-to-ningxia \
  --s3-destination-configuration \
    RoleARN=arn:aws-cn:iam::ACCOUNT-ID:role/firehose-rds-role,\
    BucketARN=arn:aws-cn:s3:::rds-logs-backup-ningxia,\
    Prefix=rds-logs/db-instance={db_instance_id}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/,\
    CompressionFormat=GZIP \
  --region cn-north-1
```

3. **Create Subscription Filters for Each Database Log Group:**

```bash
# For each RDS log group
aws logs put-subscription-filter \
  --log-group-name /aws/rds/instance/mydb-instance/error \
  --filter-name RDSErrorLogsToFirehose \
  --filter-pattern "" \
  --destination-arn arn:aws-cn:firehose:cn-north-1:ACCOUNT-ID:deliverystream/rds-logs-to-ningxia \
  --region cn-north-1
```

### Step 3: Set Up RDS Cross-Region Automated Backups

**For SQL Server (if supported):**

```bash
aws rds put-backup-policy \
  --resource-arn arn:aws-cn:rds:cn-north-1:ACCOUNT-ID:db:mydb-instance \
  --backup-policy Status=enabled,CrossRegionBackupConfiguration=[Region=cn-northwest-1,KmsKeyId=arn:aws-cn:kms:cn-northwest-1:ACCOUNT-ID:key/key-id] \
  --region cn-north-1
```

---

## Strategy 4: Centralized Backup Management with AWS Backup

### Step 1: Create Backup Vault in Ningxia

```bash
aws backup create-backup-vault \
  --backup-vault-name CentralizedLogsBackup \
  --encryption-key-arn arn:aws-cn:kms:cn-northwest-1:ACCOUNT-ID:key/key-id \
  --region cn-northwest-1 \
  --endpoint-url https://backup.cn-northwest-1.amazonaws.com.cn
```

### Step 2: Create Cross-Region Backup Plan

```json
{
  "BackupPlanName": "CrossRegionLogBackupPlan",
  "Rules": [
    {
      "RuleName": "DailyBackup",
      "TargetBackupVaultName": "CentralizedLogsBackup",
      "ScheduleExpression": "cron(0 2 ? * * *)",
      "StartWindowMinutes": 60,
      "CompletionWindowMinutes": 120,
      "Lifecycle": {
        "DeleteAfterDays": 90
      },
      "CopyActions": [
        {
          "DestinationBackupVaultArn": "arn:aws-cn:backup:cn-northwest-1:ACCOUNT-ID:backup-vault:CentralizedLogsBackup",
          "Lifecycle": {
            "DeleteAfterDays": 90
          }
        }
      ]
    }
  ]
}
```

### Step 3: Assign Resources to Backup Plan

```bash
aws backup put-backup-selection \
  --backup-plan-id backup-plan-id \
  --backup-selection '{
    "SelectionName": "LogResourcesSelection",
    "IamRoleArn": "arn:aws-cn:iam::ACCOUNT-ID:role/aws-backup-service-role",
    "Resources": [
      "arn:aws-cn:rds:cn-north-1:ACCOUNT-ID:db:*",
      "arn:aws-cn:s3:::vpc-flow-logs-*"
    ],
    "Conditions": {
      "StringEquals": {
        "aws:ResourceTag/Environment": ["Production"]
      }
    }
  }' \
  --region cn-north-1
```

---

## Implementation Timeline

### Phase 1: Foundation Setup (Week 1)
- [ ] Create S3 buckets in cn-northwest-1
- [ ] Set up IAM roles and policies
- [ ] Configure KMS keys for encryption

### Phase 2: VPC Flow Logs (Week 2)
- [ ] Configure VPC Flow Logs direct to S3
- [ ] Set up Kinesis Firehose streams
- [ ] Test cross-region log delivery

### Phase 3: EC2 Logs (Week 3)
- [ ] Deploy CloudWatch agents to EC2 instances
- [ ] Configure log groups and streams
- [ ] Set up automated export processes

### Phase 4: Database Logs (Week 4)
- [ ] Enable RDS log publishing to CloudWatch
- [ ] Configure database log streaming
- [ ] Set up cross-region backup for RDS

### Phase 5: Centralized Management (Week 5)
- [ ] Deploy AWS Backup plans
- [ ] Configure monitoring and alerting
- [ ] Perform end-to-end testing

---

## Monitoring and Alerting

### CloudWatch Alarms

```bash
# Monitor Firehose delivery failures
aws cloudwatch put-metric-alarm \
  --alarm-name "FirehoseDeliveryFailures" \
  --alarm-description "Monitor Firehose delivery failures" \
  --metric-name DeliveryToS3.Records \
  --namespace AWS/Kinesis/Firehose \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=DeliveryStreamName,Value=vpc-logs-to-ningxia \
  --region cn-north-1
```

### Cost Optimization

1. **Lifecycle Policies for S3:**
```json
{
  "Rules": [
    {
      "ID": "LogArchivingRule",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

2. **CloudWatch Logs Retention:**
```bash
aws logs put-retention-policy \
  --log-group-name /aws/vpc/flowlogs \
  --retention-in-days 7 \
  --region cn-north-1
```

---

## Security Best Practices

### 1. Encryption in Transit and at Rest
- Enable S3 bucket encryption with KMS
- Use SSL/TLS for all API calls
- Encrypt Kinesis streams

### 2. Access Control
- Implement least privilege IAM policies
- Use resource-based policies for cross-region access
- Enable CloudTrail for audit logging

### 3. Network Security
- Use VPC endpoints where available
- Implement security groups and NACLs
- Enable GuardDuty for threat detection

---

## Troubleshooting Common Issues

### 1. Cross-Region Access Denied
**Problem:** S3 access denied when writing from Beijing to Ningxia bucket
**Solution:** Verify bucket policy allows cross-region access

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws-cn:s3:::bucket-name/*",
      "Condition": {
        "StringEquals": {
          "s3:ExistingObjectTag/source-region": "cn-north-1"
        }
      }
    }
  ]
}
```

### 2. Kinesis Firehose Delivery Failures
**Problem:** Records not being delivered to S3
**Solution:** Check CloudWatch metrics and error logs

```bash
aws firehose describe-delivery-stream \
  --delivery-stream-name vpc-logs-to-ningxia \
  --region cn-north-1
```

### 3. High Costs
**Problem:** Unexpected charges for log storage
**Solution:** Implement lifecycle policies and optimize log retention

---

## Additional Resources

- [AWS China Documentation](https://docs.amazonaws.cn)
- [AWS Backup User Guide](https://docs.aws.amazon.com/aws-backup/latest/devguide/)
- [VPC Flow Logs Guide](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [Kinesis Data Firehose Documentation](https://docs.aws.amazon.com/firehose/latest/dev/)

---

## Conclusion

This comprehensive strategy provides multiple approaches for backing up log flows from Beijing to Ningxia regions. Choose the methods that best fit your requirements for:

- **Real-time vs. Batch processing**
- **Cost optimization**
- **Compliance requirements**
- **Recovery time objectives**

Start with VPC Flow Logs direct to S3 for simplicity, then expand to include EC2 and database logs as needed. The centralized AWS Backup approach provides enterprise-grade management and compliance reporting.
