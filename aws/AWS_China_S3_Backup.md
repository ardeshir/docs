I'll walk you through the step-by-step implementation of **Strategy 2 (EC2 Logs Backup)** and **Strategy 3 (Database Logs Backup)** from the document. Let me break this down into actionable steps:I've created a comprehensive step-by-step implementation guide for both **Strategy 2 (EC2 Logs Backup)** and **Strategy 3 (Database Logs Backup)**. Here's what the implementation covers:

## **Implementation Overview:**

### **Prerequisites** (Must do first):
1. Create S3 buckets in Ningxia region for storing logs
2. Set up IAM roles and policies for Kinesis Firehose

### **Strategy 2 - EC2 Logs Backup** (includes EKS node logs):
1. **Install CloudWatch Agent** on EC2 instances/EKS nodes
2. **Configure log collection** for system, security, application, and Kubernetes logs
3. **Create cross-region pipeline** using Kinesis Firehose to stream logs to Ningxia
4. **Set up lifecycle policies** for cost optimization

### **Strategy 3 - Database Logs Backup**:
1. **Enable RDS log publishing** to CloudWatch Logs
2. **Create dedicated backup pipeline** for database logs
3. **Configure monitoring and retention** policies

## **Key Features of This Implementation:**

- **Real-time streaming** from Beijing to Ningxia using Kinesis Firehose
- **Cost optimization** with short CloudWatch retention (7 days) and S3 lifecycle policies
- **EKS compatibility** with kubelet and pod log collection
- **Monitoring setup** with CloudWatch alarms for delivery failures
- **Security best practices** with least-privilege IAM policies

## **Next Steps:**

1. **Start with Prerequisites** - Create the S3 buckets and IAM roles
2. **Begin with Strategy 2** if you want to backup EKS node logs first
3. **Add Strategy 3** if you have RDS databases to backup
4. **Test the pipeline** by checking S3 buckets for log delivery

**Important**: Make sure to replace all placeholders (like `ACCOUNT-ID`, `YOUR-DB-INSTANCE-ID`) with your actual values before running the commands.
# AWS China Log Backup Implementation: Step-by-Step Guide

## Prerequisites Setup

### 1. Create S3 Buckets in Ningxia Region (cn-northwest-1)

```bash
# Create S3 bucket for EC2 logs
aws s3api create-bucket \
  --bucket ec2-logs-backup-ningxia \
  --region cn-northwest-1 \
  --create-bucket-configuration LocationConstraint=cn-northwest-1 \
  --endpoint-url https://s3.cn-northwest-1.amazonaws.com.cn

# Create S3 bucket for RDS logs
aws s3api create-bucket \
  --bucket rds-logs-backup-ningxia \
  --region cn-northwest-1 \
  --create-bucket-configuration LocationConstraint=cn-northwest-1 \
  --endpoint-url https://s3.cn-northwest-1.amazonaws.com.cn
```

### 2. Create IAM Role for Kinesis Firehose

**Create trust policy file (firehose-trust-policy.json):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Create permissions policy file (firehose-permissions.json):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws-cn:s3:::ec2-logs-backup-ningxia",
        "arn:aws-cn:s3:::ec2-logs-backup-ningxia/*",
        "arn:aws-cn:s3:::rds-logs-backup-ningxia",
        "arn:aws-cn:s3:::rds-logs-backup-ningxia/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

**Create the IAM role:**
```bash
# Create the role
aws iam create-role \
  --role-name firehose-delivery-role \
  --assume-role-policy-document file://firehose-trust-policy.json \
  --region cn-north-1 \
  --endpoint-url https://iam.cn-north-1.amazonaws.com.cn

# Create and attach the policy
aws iam create-policy \
  --policy-name FirehoseDeliveryRolePolicy \
  --policy-document file://firehose-permissions.json \
  --region cn-north-1

aws iam attach-role-policy \
  --role-name firehose-delivery-role \
  --policy-arn arn:aws-cn:iam::ACCOUNT-ID:policy/FirehoseDeliveryRolePolicy \
  --region cn-north-1
```

---

## Strategy 2: EC2 Logs Backup Implementation

### Step 1: Install and Configure CloudWatch Agent on EC2 Instances

**1.1 Install CloudWatch Agent (on Amazon Linux 2/RHEL/CentOS):**
```bash
# Download and install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
sudo rpm -U ./amazon-cloudwatch-agent.rpm
```

**1.2 Create CloudWatch Agent Configuration:**
Create `/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json`:
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
            "file_path": "/var/log/secure",
            "log_group_name": "/aws/ec2/security-logs",
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

**For EKS Node Logs, add these additional log paths:**
```json
{
  "file_path": "/var/log/kubelet.log",
  "log_group_name": "/aws/eks/kubelet-logs",
  "log_stream_name": "{instance_id}",
  "timezone": "UTC"
},
{
  "file_path": "/var/log/pods/*/*/*.log",
  "log_group_name": "/aws/eks/pod-logs",
  "log_stream_name": "{instance_id}",
  "timezone": "UTC"
}
```

**1.3 Create IAM Role for EC2 CloudWatch Agent:**
```bash
# Create trust policy for EC2
cat > ec2-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
  --role-name CloudWatchAgentServerRole \
  --assume-role-policy-document file://ec2-trust-policy.json

# Attach AWS managed policy
aws iam attach-role-policy \
  --role-name CloudWatchAgentServerRole \
  --policy-arn arn:aws-cn:iam::aws:policy/CloudWatchAgentServerPolicy
```

**1.4 Start CloudWatch Agent:**
```bash
# Start the CloudWatch agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s
```

### Step 2: Create Cross-Region Log Backup Pipeline

**2.1 Create CloudWatch Log Groups:**
```bash
# Create log groups in Beijing region
aws logs create-log-group \
  --log-group-name /aws/ec2/system-logs \
  --region cn-north-1 \
  --endpoint-url https://logs.cn-north-1.amazonaws.com.cn

aws logs create-log-group \
  --log-group-name /aws/ec2/security-logs \
  --region cn-north-1 \
  --endpoint-url https://logs.cn-north-1.amazonaws.com.cn

aws logs create-log-group \
  --log-group-name /aws/ec2/application-logs \
  --region cn-north-1 \
  --endpoint-url https://logs.cn-north-1.amazonaws.com.cn

# For EKS
aws logs create-log-group \
  --log-group-name /aws/eks/kubelet-logs \
  --region cn-north-1 \
  --endpoint-url https://logs.cn-north-1.amazonaws.com.cn
```

**2.2 Create Kinesis Data Firehose Delivery Stream:**
```bash
aws firehose create-delivery-stream \
  --delivery-stream-name ec2-logs-to-ningxia \
  --delivery-stream-type DirectPut \
  --s3-destination-configuration \
    RoleARN=arn:aws-cn:iam::ACCOUNT-ID:role/firehose-delivery-role,\
    BucketARN=arn:aws-cn:s3:::ec2-logs-backup-ningxia,\
    Prefix=ec2-logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/,\
    CompressionFormat=GZIP,\
    BufferingHints="{SizeInMBs=5,IntervalInSeconds=300}" \
  --region cn-north-1 \
  --endpoint-url https://firehose.cn-north-1.amazonaws.com.cn
```

**2.3 Create CloudWatch Logs Subscription Filters:**
```bash
# Create subscription filter for system logs
aws logs put-subscription-filter \
  --log-group-name /aws/ec2/system-logs \
  --filter-name EC2SystemLogsToFirehose \
  --filter-pattern "" \
  --destination-arn arn:aws-cn:firehose:cn-north-1:ACCOUNT-ID:deliverystream/ec2-logs-to-ningxia \
  --region cn-north-1 \
  --endpoint-url https://logs.cn-north-1.amazonaws.com.cn

# Create subscription filter for security logs
aws logs put-subscription-filter \
  --log-group-name /aws/ec2/security-logs \
  --filter-name EC2SecurityLogsToFirehose \
  --filter-pattern "" \
  --destination-arn arn:aws-cn:firehose:cn-north-1:ACCOUNT-ID:deliverystream/ec2-logs-to-ningxia \
  --region cn-north-1

# Create subscription filter for application logs
aws logs put-subscription-filter \
  --log-group-name /aws/ec2/application-logs \
  --filter-name EC2ApplicationLogsToFirehose \
  --filter-pattern "" \
  --destination-arn arn:aws-cn:firehose:cn-north-1:ACCOUNT-ID:deliverystream/ec2-logs-to-ningxia \
  --region cn-north-1
```

### Step 3: Configure Log Retention and Lifecycle

**3.1 Set CloudWatch Logs Retention:**
```bash
# Set 7-day retention for cost optimization
aws logs put-retention-policy \
  --log-group-name /aws/ec2/system-logs \
  --retention-in-days 7 \
  --region cn-north-1

aws logs put-retention-policy \
  --log-group-name /aws/ec2/security-logs \
  --retention-in-days 7 \
  --region cn-north-1

aws logs put-retention-policy \
  --log-group-name /aws/ec2/application-logs \
  --retention-in-days 7 \
  --region cn-north-1
```

**3.2 Configure S3 Lifecycle Policy:**
```bash
# Create lifecycle policy
cat > s3-lifecycle-policy.json << EOF
{
  "Rules": [
    {
      "ID": "EC2LogArchivingRule",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "ec2-logs/"
      },
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
EOF

# Apply lifecycle policy to S3 bucket
aws s3api put-bucket-lifecycle-configuration \
  --bucket ec2-logs-backup-ningxia \
  --lifecycle-configuration file://s3-lifecycle-policy.json \
  --endpoint-url https://s3.cn-northwest-1.amazonaws.com.cn
```

---

## Strategy 3: Database Logs Backup Implementation

### Step 1: Enable RDS Log Publishing to CloudWatch

**1.1 Enable Log Publishing for MySQL/MariaDB:**
```bash
aws rds modify-db-instance \
  --db-instance-identifier YOUR-DB-INSTANCE-ID \
  --cloudwatch-logs-export-configuration LogTypesToEnable=error,general,slow-query \
  --apply-immediately \
  --region cn-north-1 \
  --endpoint-url https://rds.cn-north-1.amazonaws.com.cn
```

**1.2 Enable Log Publishing for PostgreSQL:**
```bash
aws rds modify-db-instance \
  --db-instance-identifier YOUR-DB-INSTANCE-ID \
  --cloudwatch-logs-export-configuration LogTypesToEnable=postgresql \
  --apply-immediately \
  --region cn-north-1 \
  --endpoint-url https://rds.cn-north-1.amazonaws.com.cn
```

**1.3 Verify Log Groups Created:**
```bash
# List RDS log groups to verify they were created
aws logs describe-log-groups \
  --log-group-name-prefix /aws/rds/instance \
  --region cn-north-1 \
  --endpoint-url https://logs.cn-north-1.amazonaws.com.cn
```

### Step 2: Create RDS Log Backup Pipeline

**2.1 Create Kinesis Firehose for Database Logs:**
```bash
aws firehose create-delivery-stream \
  --delivery-stream-name rds-logs-to-ningxia \
  --delivery-stream-type DirectPut \
  --s3-destination-configuration \
    RoleARN=arn:aws-cn:iam::ACCOUNT-ID:role/firehose-delivery-role,\
    BucketARN=arn:aws-cn:s3:::rds-logs-backup-ningxia,\
    Prefix=rds-logs/db-instance-id=YOUR-DB-INSTANCE-ID/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/,\
    CompressionFormat=GZIP,\
    BufferingHints="{SizeInMBs=5,IntervalInSeconds=300}" \
  --region cn-north-1 \
  --endpoint-url https://firehose.cn-north-1.amazonaws.com.cn
```

**2.2 Create Subscription Filters for Each Database Log Type:**

**For MySQL Error Logs:**
```bash
aws logs put-subscription-filter \
  --log-group-name /aws/rds/instance/YOUR-DB-INSTANCE-ID/error \
  --filter-name RDSErrorLogsToFirehose \
  --filter-pattern "" \
  --destination-arn arn:aws-cn:firehose:cn-north-1:ACCOUNT-ID:deliverystream/rds-logs-to-ningxia \
  --region cn-north-1 \
  --endpoint-url https://logs.cn-north-1.amazonaws.com.cn
```

**For MySQL General Logs:**
```bash
aws logs put-subscription-filter \
  --log-group-name /aws/rds/instance/YOUR-DB-INSTANCE-ID/general \
  --filter-name RDSGeneralLogsToFirehose \
  --filter-pattern "" \
  --destination-arn arn:aws-cn:firehose:cn-north-1:ACCOUNT-ID:deliverystream/rds-logs-to-ningxia \
  --region cn-north-1
```

**For MySQL Slow Query Logs:**
```bash
aws logs put-subscription-filter \
  --log-group-name /aws/rds/instance/YOUR-DB-INSTANCE-ID/slowquery \
  --filter-name RDSSlowQueryLogsToFirehose \
  --filter-pattern "" \
  --destination-arn arn:aws-cn:firehose:cn-north-1:ACCOUNT-ID:deliverystream/rds-logs-to-ningxia \
  --region cn-north-1
```

### Step 3: Set Up RDS Log Retention and Monitoring

**3.1 Configure Log Retention:**
```bash
# Set retention for RDS log groups (7 days for cost optimization)
aws logs put-retention-policy \
  --log-group-name /aws/rds/instance/YOUR-DB-INSTANCE-ID/error \
  --retention-in-days 7 \
  --region cn-north-1

aws logs put-retention-policy \
  --log-group-name /aws/rds/instance/YOUR-DB-INSTANCE-ID/general \
  --retention-in-days 7 \
  --region cn-north-1

aws logs put-retention-policy \
  --log-group-name /aws/rds/instance/YOUR-DB-INSTANCE-ID/slowquery \
  --retention-in-days 7 \
  --region cn-north-1
```

---

## Monitoring and Verification

### Step 1: Create CloudWatch Alarms

**Monitor Firehose Delivery Failures:**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "EC2-Firehose-Delivery-Failures" \
  --alarm-description "Monitor EC2 log delivery failures to Ningxia" \
  --metric-name DeliveryToS3.Records \
  --namespace AWS/Kinesis/Firehose \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=DeliveryStreamName,Value=ec2-logs-to-ningxia \
  --region cn-north-1 \
  --endpoint-url https://monitoring.cn-north-1.amazonaws.com.cn

aws cloudwatch put-metric-alarm \
  --alarm-name "RDS-Firehose-Delivery-Failures" \
  --alarm-description "Monitor RDS log delivery failures to Ningxia" \
  --metric-name DeliveryToS3.Records \
  --namespace AWS/Kinesis/Firehose \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=DeliveryStreamName,Value=rds-logs-to-ningxia \
  --region cn-north-1
```

### Step 2: Verify Log Delivery

**Check S3 buckets for log files:**
```bash
# Check EC2 logs in Ningxia S3 bucket
aws s3 ls s3://ec2-logs-backup-ningxia/ec2-logs/ --recursive \
  --endpoint-url https://s3.cn-northwest-1.amazonaws.com.cn

# Check RDS logs in Ningxia S3 bucket
aws s3 ls s3://rds-logs-backup-ningxia/rds-logs/ --recursive \
  --endpoint-url https://s3.cn-northwest-1.amazonaws.com.cn
```

**Monitor Firehose streams:**
```bash
# Check EC2 Firehose stream status
aws firehose describe-delivery-stream \
  --delivery-stream-name ec2-logs-to-ningxia \
  --region cn-north-1 \
  --endpoint-url https://firehose.cn-north-1.amazonaws.com.cn

# Check RDS Firehose stream status
aws firehose describe-delivery-stream \
  --delivery-stream-name rds-logs-to-ningxia \
  --region cn-north-1
```

---

## Important Notes

1. **Replace placeholders:**
   - `ACCOUNT-ID` with your actual AWS account ID
   - `YOUR-DB-INSTANCE-ID` with your actual RDS instance ID
   - Modify file paths according to your application needs

2. **EKS Specific Considerations:**
   - For EKS clusters, also consider logging from pods using Fluent Bit or similar log shippers
   - Monitor kubelet and container runtime logs
   - Consider using AWS for Fluent Bit for more advanced log routing

3. **Cost Optimization:**
   - Short CloudWatch logs retention (7 days)
   - S3 lifecycle policies to move data to cheaper storage classes
   - Monitor and adjust Firehose buffering settings

4. **Security:**
   - Enable S3 bucket encryption
   - Use least-privilege IAM policies
   - Monitor access with CloudTrail

This implementation will continuously stream your EC2 and database logs from Beijing to Ningxia region for backup and disaster recovery purposes.


