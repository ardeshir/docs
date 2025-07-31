# AWS Logs Backup Strategy from Beijing to Ningxia v2

A comprehensive strategy for backing up critical log data from the AWS China (Beijing) Region (cn-north-1) to the AWS China (Ningxia) Region (cn-northwest-1) is essential for disaster recovery and business continuity. This document outlines a robust, step-by-step approach for securely backing up EC2 instance logs, RDS database logs, and VPC Flow Logs.

**Key Architectural Principles:**

*   **Centralized Logging:** The core of this strategy is to first consolidate all log types into a central, durable, and cost-effective storage service within the source region. Amazon S3 is the ideal service for this purpose.
*   **Cross-Region Replication:** Once logs are stored in Amazon S3 in the Beijing region, we will leverage S3 Cross-Region Replication (CRR) to automatically and asynchronously copy the log data to a bucket in the Ningxia region.
*   **Security and Compliance:** All data transfer and storage will be configured with security best practices, including encryption at rest and in transit. It's crucial to remember that AWS China Regions are operated by local partners (Sinnet in Beijing and NWCD in Ningxia) and have their own account and credential systems, which are distinct from global AWS accounts. All operations must comply with Chinese laws and regulations regarding data localization and transfer.

### 1. Backing Up EC2 Instance Logs

EC2 instance logs, which include application logs and system-level logs, are not centrally managed by default. The recommended approach is to use the Amazon CloudWatch Agent to collect these logs and send them to a centralized location.

#### Step 1: Install and Configure the CloudWatch Agent on EC2 Instances

1.  **IAM Role for EC2:** Create an IAM role with the `CloudWatchAgentServerPolicy` attached. This policy grants the EC2 instance permission to send logs and metrics to CloudWatch.
2.  **Install the CloudWatch Agent:** Connect to your EC2 instances in `cn-north-1` and install the CloudWatch Agent. The installation process varies depending on the operating system (Amazon Linux, Ubuntu, Windows Server).
3.  **Configure the CloudWatch Agent:** Create a configuration file for the agent (typically `config.json`). In this file, specify which log files to monitor (e.g., `/var/log/app.log`, `/var/log/messages`). You can configure the agent to send these logs to Amazon CloudWatch Logs.

#### Step 2: Archive Logs from CloudWatch to Amazon S3 in Beijing (`cn-north-1`)

To facilitate long-term storage and cross-region backup, export the log data from CloudWatch Logs to an S3 bucket in the Beijing region.

1.  **Create an S3 Bucket in `cn-north-1`:** In the Beijing region, create a new S3 bucket to serve as the primary storage for your logs. Enable versioning on this bucket to protect against accidental deletions.
2.  **Create a CloudWatch Logs Export Task:** In the CloudWatch console, navigate to your log group, and from the "Actions" menu, select "Export data to Amazon S3". Configure the export to the S3 bucket you created. You can set up a recurring export task to automate this process.

Alternatively, for a more real-time approach, you can use Amazon Kinesis Data Firehose to stream logs from CloudWatch Logs directly to your S3 bucket in Beijing.

#### Step 3: Replicate Logs from Beijing to Ningxia (`cn-northwest-1`)

With your logs now in an S3 bucket in Beijing, you can replicate them to Ningxia.

1.  **Create a Destination S3 Bucket in `cn-northwest-1`:** In the Ningxia region, create a new S3 bucket to receive the replicated logs.
2.  **Enable S3 Cross-Region Replication (CRR):**
    *   In the source S3 bucket's (in Beijing) management console, navigate to the "Management" tab and select "Replication Rules".
    *   Create a new replication rule.
    *   Choose the destination bucket in the `cn-northwest-1` region.
    *   Create or specify an IAM role that S3 can assume to replicate objects on your behalf. AWS can create this role for you.
    *   You can choose to replicate all objects or filter by prefix or object tags.

### 2. Backing Up Database (RDS) Logs

For Amazon RDS, you have two types of logs to consider: automated backups (including transaction logs) and database engine logs (e.g., error logs, slow query logs).

#### Step 1: Enable Cross-Region Automated Backups for RDS

AWS provides a managed feature for cross-region backups of RDS instances, which is available in both AWS China regions.

1.  **Enable Automated Backups:** In the Amazon RDS console in the Beijing region, ensure that automated backups are enabled for your database instance.
2.  **Configure Cross-Region Backups:**
    *   Modify your RDS instance.
    *   Under the "Backup" section, you will find the option for "Cross-Region backup".
    *   Select the destination region (`cn-northwest-1`).
    *   Specify the backup retention period for the replicated backups.
    *   If your source RDS instance is encrypted, you will need to specify a KMS key in the destination region for the replicated backups to be encrypted with.

This process automatically replicates your DB snapshots and transaction logs to the Ningxia region, enabling point-in-time recovery in the event of a disaster.

#### Step 2: Back up Database Engine Logs

Database engine logs can be published to CloudWatch Logs and then archived to S3.

1.  **Publish RDS Logs to CloudWatch Logs:**
    *   In the RDS console, modify your DB instance.
    *   In the "Log exports" section, select the log types you want to publish to CloudWatch Logs (e.g., Audit Log, Error Log, Slow Query Log).
2.  **Archive Logs from CloudWatch to S3:** Follow the same procedure as outlined in "EC2 Instance Logs - Step 2" to export these logs from CloudWatch Logs to your S3 bucket in Beijing.
3.  **Replicate Logs from S3 to Ningxia:** Use the S3 Cross-Region Replication you configured earlier to automatically copy these database logs to the S3 bucket in Ningxia.

### 3. Backing Up VPC Traffic Flow Logs

VPC Flow Logs capture information about the IP traffic going to and from network interfaces in your VPC. Fortunately, VPC Flow Logs can be delivered directly to Amazon S3 in the AWS China regions.

#### Step 1: Create a VPC Flow Log Subscription to S3 in Beijing (`cn-north-1`)

1.  **Create an S3 Bucket for Flow Logs:** If you haven't already, create an S3 bucket in the Beijing region to store your VPC Flow Logs.
2.  **Create the Flow Log:**
    *   In the VPC console, select the VPC you want to monitor.
    *   On the "Flow Logs" tab, click "Create flow log".
    *   Configure the filter (e.g., "All" to capture all traffic).
    *   Set the "Destination" to "Send to an S3 bucket".
    *   Provide the ARN of your S3 bucket in `cn-north-1`.
    *   You can also configure the log record format.

#### Step 2: Replicate VPC Flow Logs from Beijing to Ningxia

Since the VPC Flow Logs are now being delivered to your S3 bucket in Beijing, the existing S3 Cross-Region Replication rule you set up will automatically handle the backup to the Ningxia region. No additional configuration is needed for this step.

### Summary of the Backup Strategy

This multi-faceted strategy ensures that all your critical log data is durably stored and backed up across two geographically separate regions within AWS China.

| **Log Type** | **Source (Beijing - cn-north-1)** | **Backup (Ningxia - cn-northwest-1)** |
| :--- | :--- | :--- |
| **EC2 Logs** | CloudWatch Agent -> CloudWatch Logs -> S3 Bucket | S3 Cross-Region Replication -> S3 Bucket |
| **RDS Backups** | RDS Automated Backups -> Managed Replication | RDS Cross-Region Automated Backups |
| **RDS Logs** | RDS -> CloudWatch Logs -> S3 Bucket | S3 Cross-Region Replication -> S3 Bucket |
| **VPC Flow Logs**| VPC -> S3 Bucket | S3 Cross-Region Replication -> S3 Bucket |

By following these steps, you can build a robust and automated log backup solution that enhances the resilience and availability of your applications running in the AWS China regions.
