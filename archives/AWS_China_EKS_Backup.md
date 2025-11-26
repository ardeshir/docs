I'll create a detailed, EKS-specific implementation guide with all the clarifications and specific steps for your EKS setup.I've created a comprehensive, EKS-focused implementation guide that clarifies all the specific steps. Here are the key clarifications for your EKS setup:

## **Key EKS-Specific Clarifications:**

### **1. EKS Log Sources Explained:**
- **Node-level logs**: kubelet, kube-proxy, container runtime, system logs
- **Container logs**: Individual pod container logs via Fluent Bit
- **System logs**: Bootstrap, security, and system messages

### **2. Two-Tier Logging Approach:**
- **CloudWatch Agent DaemonSet**: Collects node-level system logs
- **Fluent Bit DaemonSet**: Collects container and application logs from pods

### **3. Complete Kubernetes Deployments:**
- Proper RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding)
- DaemonSets that run on all nodes
- ConfigMaps for log configuration
- Namespace isolation (`amazon-cloudwatch`)

### **4. EKS-Specific Configuration:**
```bash
# Environment variables for easy setup
export EKS_CLUSTER_NAME="your-cluster-name"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

### **5. Real-Time Verification Steps:**
- Check pod deployment across all nodes
- Verify log groups are receiving data
- Confirm S3 delivery in Ningxia region
- Monitor Firehose stream health

## **What Makes This EKS-Specific:**

1. **Kubernetes-Native Deployment**: Uses DaemonSets instead of installing agents on individual EC2 instances
2. **Container Log Collection**: Captures logs from all pods and containers
3. **Cluster-Wide Coverage**: Automatically deploys to new nodes as they join
4. **EKS Control Plane Integration**: Separate from AWS-managed control plane logs

## **Implementation Order:**
1. **Start with Prerequisites** (S3 buckets, IAM roles)
2. **Deploy CloudWatch Agent** for node logs
3. **Deploy Fluent Bit** for container logs  
4. **Configure RDS logs** if you have databases
5. **Set up monitoring** and verify delivery

## **Key Benefits:**
- **Automatic scaling**: New EKS nodes automatically get logging agents
- **Real-time streaming**: Logs flow immediately to Ningxia region
- **Cost optimized**: 7-day CloudWatch retention + S3 lifecycle policies
- **Container awareness**: Captures Kubernetes metadata with logs

The guide now includes actual kubectl commands, complete YAML manifests, and specific verification steps for your EKS environment. Each step includes the exact commands you need to run with proper AWS China endpoints.

# EKS-Focused AWS China Log Backup: Complete Implementation Guide

## Prerequisites Setup (Detailed)

### 1. Gather Your Information First

Before starting, collect these details:
```bash
# Your AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $AWS_ACCOUNT_ID"

# Your EKS cluster name
export EKS_CLUSTER_NAME="your-eks-cluster-name"

# Your EKS node group name
export EKS_NODEGROUP_NAME="your-nodegroup-name"

# List your EKS nodes
kubectl get nodes -o wide
```

### 2. Create S3 Buckets with Proper Configuration

```bash
# Set variables
export REGION_BEIJING="cn-north-1"
export REGION_NINGXIA="cn-northwest-1"
export S3_BUCKET_EKS="eks-logs-backup-ningxia"
export S3_BUCKET_RDS="rds-logs-backup-ningxia"

# Create S3 bucket for EKS logs with versioning
aws s3api create-bucket \
  --bucket $S3_BUCKET_EKS \
  --region $REGION_NINGXIA \
  --create-bucket-configuration LocationConstraint=$REGION_NINGXIA \
  --endpoint-url https://s3.$REGION_NINGXIA.amazonaws.com.cn

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $S3_BUCKET_EKS \
  --versioning-configuration Status=Enabled \
  --endpoint-url https://s3.$REGION_NINGXIA.amazonaws.com.cn

# Create bucket policy for cross-region access
cat > s3-bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws-cn:s3:::$S3_BUCKET_EKS",
        "arn:aws-cn:s3:::$S3_BUCKET_EKS/*"
      ],
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    }
  ]
}
EOF

# Apply bucket policy
aws s3api put-bucket-policy \
  --bucket $S3_BUCKET_EKS \
  --policy file://s3-bucket-policy.json \
  --endpoint-url https://s3.$REGION_NINGXIA.amazonaws.com.cn
```

### 3. Create IAM Roles with Complete Permissions

**3.1 Create Kinesis Firehose Service Role:**
```bash
# Trust policy for Firehose
cat > firehose-trust-policy.json << EOF
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
EOF

# Comprehensive permissions policy
cat > firehose-permissions.json << EOF
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
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "arn:aws-cn:s3:::$S3_BUCKET_EKS",
        "arn:aws-cn:s3:::$S3_BUCKET_EKS/*",
        "arn:aws-cn:s3:::$S3_BUCKET_RDS",
        "arn:aws-cn:s3:::$S3_BUCKET_RDS/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents",
        "logs:CreateLogGroup",
        "logs:CreateLogStream"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:DescribeStream",
        "kinesis:GetShardIterator",
        "kinesis:GetRecords"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create role and policy
aws iam create-role \
  --role-name EKSFirehoseDeliveryRole \
  --assume-role-policy-document file://firehose-trust-policy.json \
  --endpoint-url https://iam.$REGION_BEIJING.amazonaws.com.cn

aws iam create-policy \
  --policy-name EKSFirehoseDeliveryRolePolicy \
  --policy-document file://firehose-permissions.json \
  --endpoint-url https://iam.$REGION_BEIJING.amazonaws.com.cn

aws iam attach-role-policy \
  --role-name EKSFirehoseDeliveryRole \
  --policy-arn arn:aws-cn:iam::$AWS_ACCOUNT_ID:policy/EKSFirehoseDeliveryRolePolicy \
  --endpoint-url https://iam.$REGION_BEIJING.amazonaws.com.cn
```

**3.2 Update EKS Node Group IAM Role:**
```bash
# Get your existing EKS node group role
export EKS_NODE_ROLE=$(aws eks describe-nodegroup \
  --cluster-name $EKS_CLUSTER_NAME \
  --nodegroup-name $EKS_NODEGROUP_NAME \
  --region $REGION_BEIJING \
  --query 'nodegroup.nodeRole' --output text | cut -d'/' -f2)

echo "EKS Node Role: $EKS_NODE_ROLE"

# Create additional policy for CloudWatch agent
cat > eks-cloudwatch-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags",
        "logs:PutLogEvents",
        "logs:CreateLogGroup",
        "logs:CreateLogStream"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create and attach policy to EKS node role
aws iam create-policy \
  --policy-name EKSCloudWatchAgentPolicy \
  --policy-document file://eks-cloudwatch-policy.json

aws iam attach-role-policy \
  --role-name $EKS_NODE_ROLE \
  --policy-arn arn:aws-cn:iam::$AWS_ACCOUNT_ID:policy/EKSCloudWatchAgentPolicy
```

---

## EKS-Specific Log Backup Implementation

### Step 1: Understand EKS Log Sources

**EKS generates multiple types of logs:**
1. **EKS Control Plane Logs** (managed by AWS, separate configuration)
2. **Node-level logs** (what we're backing up):
   - `/var/log/kubelet.log` - Kubelet service logs
   - `/var/log/kube-proxy.log` - Kube-proxy logs
   - `/var/log/docker` or `/var/log/containerd` - Container runtime logs
   - `/var/log/pods/*/*/*.log` - Individual pod container logs
   - `/var/log/messages` - System logs
   - `/var/log/secure` - Security logs
   - `/var/log/cloud-init.log` - Bootstrap logs

### Step 2: Deploy CloudWatch Agent to EKS Nodes

**2.1 Create CloudWatch Agent Configuration for EKS:**
```bash
# Create namespace for CloudWatch agent
kubectl create namespace amazon-cloudwatch

# Create ConfigMap with EKS-specific configuration
cat > cwagentconfig.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cwagentconfig
  namespace: amazon-cloudwatch
data:
  cwagentconfig.json: |
    {
      "agent": {
        "region": "$REGION_BEIJING",
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
      },
      "logs": {
        "metrics_collected": {
          "kubernetes": {
            "cluster_name": "$EKS_CLUSTER_NAME",
            "metrics_collection_interval": 60
          }
        },
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/kubelet.log",
                "log_group_name": "/aws/eks/$EKS_CLUSTER_NAME/kubelet",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              },
              {
                "file_path": "/var/log/kube-proxy.log",
                "log_group_name": "/aws/eks/$EKS_CLUSTER_NAME/kube-proxy",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              },
              {
                "file_path": "/var/log/docker",
                "log_group_name": "/aws/eks/$EKS_CLUSTER_NAME/docker",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              },
              {
                "file_path": "/var/log/messages",
                "log_group_name": "/aws/eks/$EKS_CLUSTER_NAME/system",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              },
              {
                "file_path": "/var/log/secure",
                "log_group_name": "/aws/eks/$EKS_CLUSTER_NAME/secure",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              },
              {
                "file_path": "/var/log/cloud-init.log",
                "log_group_name": "/aws/eks/$EKS_CLUSTER_NAME/cloud-init",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              }
            ]
          }
        }
      }
    }
EOF

kubectl apply -f cwagentconfig.yaml
```

**2.2 Deploy CloudWatch Agent as DaemonSet:**
```bash
cat > cwagent-daemonset.yaml << EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cloudwatch-agent
  namespace: amazon-cloudwatch
spec:
  selector:
    matchLabels:
      name: cloudwatch-agent
  template:
    metadata:
      labels:
        name: cloudwatch-agent
    spec:
      serviceAccountName: cloudwatch-agent
      containers:
      - name: cloudwatch-agent
        image: public.ecr.aws/cloudwatch-agent/cloudwatch-agent:1.247348.0b251302
        resources:
          limits:
            cpu:  200m
            memory: 200Mi
          requests:
            cpu: 200m
            memory: 200Mi
        env:
        - name: AWS_REGION
          value: $REGION_BEIJING
        - name: K8S_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: HOST_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        - name: HOST_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: K8S_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        volumeMounts:
        - name: cwagentconfig
          mountPath: /etc/cwagentconfig
        - name: rootfs
          mountPath: /rootfs
          readOnly: true
        - name: dockersock
          mountPath: /var/run/docker.sock
          readOnly: true
        - name: varlibdocker
          mountPath: /var/lib/docker
          readOnly: true
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: sys
          mountPath: /sys
          readOnly: true
        - name: devdisk
          mountPath: /dev/disk
          readOnly: true
      volumes:
      - name: cwagentconfig
        configMap:
          name: cwagentconfig
      - name: rootfs
        hostPath:
          path: /
      - name: dockersock
        hostPath:
          path: /var/run/docker.sock
      - name: varlibdocker
        hostPath:
          path: /var/lib/docker
      - name: varlog
        hostPath:
          path: /var/log
      - name: sys
        hostPath:
          path: /sys
      - name: devdisk
        hostPath:
          path: /dev/disk/
      terminationGracePeriodSeconds: 60
      hostNetwork: true
EOF

# Create service account and role binding
cat > cwagent-serviceaccount.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloudwatch-agent
  namespace: amazon-cloudwatch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cloudwatch-agent-role
rules:
  - apiGroups: [""]
    resources: ["pods", "nodes", "endpoints"]
    verbs: ["list", "watch"]
  - apiGroups: ["apps"]
    resources: ["replicasets"]
    verbs: ["list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["list", "watch"]
  - apiGroups: [""]
    resources: ["nodes/proxy"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["nodes/stats", "configmaps", "events"]
    verbs: ["create", "get"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["update"]
  - nonResourceURLs: ["/metrics"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cloudwatch-agent-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cloudwatch-agent-role
subjects:
  - kind: ServiceAccount
    name: cloudwatch-agent
    namespace: amazon-cloudwatch
EOF

# Deploy CloudWatch agent
kubectl apply -f cwagent-serviceaccount.yaml
kubectl apply -f cwagent-daemonset.yaml

# Verify deployment
kubectl get pods -n amazon-cloudwatch
kubectl logs -n amazon-cloudwatch -l name=cloudwatch-agent
```

### Step 3: Create CloudWatch Log Groups for EKS

```bash
# Create all EKS-related log groups
declare -a LOG_GROUPS=(
  "/aws/eks/$EKS_CLUSTER_NAME/kubelet"
  "/aws/eks/$EKS_CLUSTER_NAME/kube-proxy" 
  "/aws/eks/$EKS_CLUSTER_NAME/docker"
  "/aws/eks/$EKS_CLUSTER_NAME/system"
  "/aws/eks/$EKS_CLUSTER_NAME/secure"
  "/aws/eks/$EKS_CLUSTER_NAME/cloud-init"
)

# Create each log group
for LOG_GROUP in "${LOG_GROUPS[@]}"
do
  echo "Creating log group: $LOG_GROUP"
  aws logs create-log-group \
    --log-group-name "$LOG_GROUP" \
    --region $REGION_BEIJING \
    --endpoint-url https://logs.$REGION_BEIJING.amazonaws.com.cn
  
  # Set retention policy (7 days for cost optimization)
  aws logs put-retention-policy \
    --log-group-name "$LOG_GROUP" \
    --retention-in-days 7 \
    --region $REGION_BEIJING \
    --endpoint-url https://logs.$REGION_BEIJING.amazonaws.com.cn
done
```

### Step 4: Create Kinesis Firehose Delivery Stream for EKS Logs

```bash
# Create Firehose delivery stream with EKS-specific configuration
aws firehose create-delivery-stream \
  --delivery-stream-name eks-logs-to-ningxia \
  --delivery-stream-type DirectPut \
  --s3-destination-configuration '{
    "RoleARN": "arn:aws-cn:iam::'$AWS_ACCOUNT_ID':role/EKSFirehoseDeliveryRole",
    "BucketARN": "arn:aws-cn:s3:::'$S3_BUCKET_EKS'",
    "Prefix": "eks-logs/cluster='$EKS_CLUSTER_NAME'/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/hour=!{timestamp:HH}/",
    "ErrorOutputPrefix": "errors/",
    "BufferingHints": {
      "SizeInMBs": 5,
      "IntervalInSeconds": 60
    },
    "CompressionFormat": "GZIP",
    "CloudWatchLoggingOptions": {
      "Enabled": true,
      "LogGroupName": "/aws/kinesisfirehose/eks-logs-to-ningxia"
    }
  }' \
  --region $REGION_BEIJING \
  --endpoint-url https://firehose.$REGION_BEIJING.amazonaws.com.cn

# Verify Firehose stream creation
aws firehose describe-delivery-stream \
  --delivery-stream-name eks-logs-to-ningxia \
  --region $REGION_BEIJING \
  --endpoint-url https://firehose.$REGION_BEIJING.amazonaws.com.cn
```

### Step 5: Create Subscription Filters for Each EKS Log Group

```bash
# Function to create subscription filter
create_subscription_filter() {
  local LOG_GROUP_NAME=$1
  local FILTER_NAME=$2
  
  echo "Creating subscription filter for $LOG_GROUP_NAME"
  
  aws logs put-subscription-filter \
    --log-group-name "$LOG_GROUP_NAME" \
    --filter-name "$FILTER_NAME" \
    --filter-pattern "" \
    --destination-arn "arn:aws-cn:firehose:$REGION_BEIJING:$AWS_ACCOUNT_ID:deliverystream/eks-logs-to-ningxia" \
    --region $REGION_BEIJING \
    --endpoint-url https://logs.$REGION_BEIJING.amazonaws.com.cn
}

# Create subscription filters for all log groups
create_subscription_filter "/aws/eks/$EKS_CLUSTER_NAME/kubelet" "EKSKubeletLogsToFirehose"
create_subscription_filter "/aws/eks/$EKS_CLUSTER_NAME/kube-proxy" "EKSKubeProxyLogsToFirehose"
create_subscription_filter "/aws/eks/$EKS_CLUSTER_NAME/docker" "EKSDockerLogsToFirehose"
create_subscription_filter "/aws/eks/$EKS_CLUSTER_NAME/system" "EKSSystemLogsToFirehose"
create_subscription_filter "/aws/eks/$EKS_CLUSTER_NAME/secure" "EKSSecureLogsToFirehose"
create_subscription_filter "/aws/eks/$EKS_CLUSTER_NAME/cloud-init" "EKSCloudInitLogsToFirehose"
```

---

## Pod-Level Log Collection with Fluent Bit (Advanced)

### Step 6: Deploy Fluent Bit for Container Logs

**6.1 Create Fluent Bit Configuration:**
```bash
cat > fluent-bit-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: amazon-cloudwatch
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush                     5
        Grace                     30
        Log_Level                 info
        Daemon                    off
        Parsers_File              parsers.conf
        HTTP_Server               On
        HTTP_Listen               0.0.0.0
        HTTP_Port                 2020
        storage.path              /var/fluent-bit/state/flb-storage/
        storage.sync              normal
        storage.checksum          off
        storage.backlog.mem_limit 5M
        
    [INPUT]
        Name                tail
        Tag                 application.*
        Exclude_Path        /var/log/containers/cloudwatch-agent*, /var/log/containers/fluent-bit*
        Path                /var/log/containers/*.log
        Parser              cri
        DB                  /var/fluent-bit/state/flb_container.db
        Mem_Buf_Limit       50MB
        Skip_Long_Lines     On
        Refresh_Interval    10
        storage.type        filesystem
        Read_from_Head      Off

    [INPUT]
        Name                tail
        Tag                 dataplane.systemd.*
        Path                /var/log/journal
        Parser              systemd
        DB                  /var/fluent-bit/state/flb_journal.db
        Mem_Buf_Limit       50MB
        Skip_Long_Lines     On
        Refresh_Interval    10
        storage.type        filesystem
        Read_from_Head      Off

    [FILTER]
        Name                kubernetes
        Match               application.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_Tag_Prefix     application.var.log.containers.
        Merge_Log           On
        Merge_Log_Key       log_processed
        K8S-Logging.Parser  On
        K8S-Logging.Exclude Off
        Labels              Off
        Annotations         Off

    [OUTPUT]
        Name                cloudwatch_logs
        Match               application.*
        region              $REGION_BEIJING
        log_group_name      /aws/eks/$EKS_CLUSTER_NAME/application
        log_stream_prefix   eks-
        auto_create_group   On
        extra_user_agent    container-insights

    [OUTPUT]
        Name                cloudwatch_logs
        Match               dataplane.systemd.*
        region              $REGION_BEIJING
        log_group_name      /aws/eks/$EKS_CLUSTER_NAME/dataplane
        log_stream_prefix   eks-
        auto_create_group   On
        extra_user_agent    container-insights

  parsers.conf: |
    [PARSER]
        Name                cri
        Format              regex
        Regex               ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<message>.*)$
        Time_Key            time
        Time_Format         %Y-%m-%dT%H:%M:%S.%L%z

    [PARSER]
        Name                systemd
        Format              regex
        Regex               ^\<(?<pri>[0-9]+)\>(?<time>[^ ]* {1,2}[^ ]* [^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$
        Time_Key            time
        Time_Format         %b %d %H:%M:%S
EOF

kubectl apply -f fluent-bit-config.yaml
```

**6.2 Deploy Fluent Bit DaemonSet:**
```bash
cat > fluent-bit-daemonset.yaml << EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: amazon-cloudwatch
  labels:
    k8s-app: fluent-bit
spec:
  selector:
    matchLabels:
      k8s-app: fluent-bit
  template:
    metadata:
      labels:
        k8s-app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      containers:
      - name: fluent-bit
        image: public.ecr.aws/aws-observability/aws-for-fluent-bit:stable
        imagePullPolicy: Always
        env:
        - name: AWS_REGION
          value: $REGION_BEIJING
        - name: CLUSTER_NAME
          value: $EKS_CLUSTER_NAME
        - name: HTTP_SERVER
          value: "On"
        - name: HTTP_PORT
          value: "2020"
        - name: READ_FROM_HEAD
          value: "Off"
        - name: READ_FROM_TAIL
          value: "On"
        - name: HOST_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
        - name: CI_VERSION
          value: "k8s/1.3.9"
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 500m
            memory: 100Mi
        volumeMounts:
        - name: fluentbitstate
          mountPath: /var/fluent-bit/state
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: fluent-bit-config
          mountPath: /fluent-bit/etc/
        - name: runlogjournal
          mountPath: /run/log/journal
          readOnly: true
        - name: dmesg
          mountPath: /var/log/dmesg
          readOnly: true
      terminationGracePeriodSeconds: 10
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      volumes:
      - name: fluentbitstate
        hostPath:
          path: /var/fluent-bit/state
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: fluent-bit-config
        configMap:
          name: fluent-bit-config
      - name: runlogjournal
        hostPath:
          path: /run/log/journal
      - name: dmesg
        hostPath:
          path: /var/log/dmesg
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluent-bit
  namespace: amazon-cloudwatch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluent-bit-role
rules:
  - nonResourceURLs:
      - /metrics
    verbs:
      - get
  - apiGroups: [""]
    resources:
      - namespaces
      - pods
      - pods/logs
      - nodes
      - nodes/proxy
    verbs:
      - get
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluent-bit-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fluent-bit-role
subjects:
  - kind: ServiceAccount
    name: fluent-bit
    namespace: amazon-cloudwatch
EOF

kubectl apply -f fluent-bit-daemonset.yaml

# Verify Fluent Bit deployment
kubectl get pods -n amazon-cloudwatch -l k8s-app=fluent-bit
```

### Step 7: Create Additional Log Groups and Subscription Filters for Pod Logs

```bash
# Create log groups for application and dataplane logs
aws logs create-log-group \
  --log-group-name "/aws/eks/$EKS_CLUSTER_NAME/application" \
  --region $REGION_BEIJING \
  --endpoint-url https://logs.$REGION_BEIJING.amazonaws.com.cn

aws logs create-log-group \
  --log-group-name "/aws/eks/$EKS_CLUSTER_NAME/dataplane" \
  --region $REGION_BEIJING \
  --endpoint-url https://logs.$REGION_BEIJING.amazonaws.com.cn

# Set retention policies
aws logs put-retention-policy \
  --log-group-name "/aws/eks/$EKS_CLUSTER_NAME/application" \
  --retention-in-days 7 \
  --region $REGION_BEIJING

aws logs put-retention-policy \
  --log-group-name "/aws/eks/$EKS_CLUSTER_NAME/dataplane" \
  --retention-in-days 7 \
  --region $REGION_BEIJING

# Create subscription filters for pod logs
create_subscription_filter "/aws/eks/$EKS_CLUSTER_NAME/application" "EKSApplicationLogsToFirehose"
create_subscription_filter "/aws/eks/$EKS_CLUSTER_NAME/dataplane" "EKSDataplaneLogsToFirehose"
```

---

## Database Logs Backup (RDS) Implementation

### Step 8: Enable and Configure RDS Log Publishing

```bash
# List your RDS instances to get the correct identifier
aws rds describe-db-instances \
  --region $REGION_BEIJING \
  --endpoint-url https://rds.$REGION_BEIJING.amazonaws.com.cn \
  --query 'DBInstances[*].[DBInstanceIdentifier,Engine,DBInstanceStatus]' \
  --output table

# Set your RDS instance identifier
export RDS_INSTANCE_ID="your-rds-instance-id"

# For MySQL/MariaDB - Enable error, general, and slow query logs
aws rds modify-db-instance \
  --db-instance-identifier $RDS_INSTANCE_ID \
  --cloudwatch-logs-export-configuration LogTypesToEnable=error,general,slow-query \
  --apply-immediately \
  --region $REGION_BEIJING \
  --endpoint-url https://rds.$REGION_BEIJING.amazonaws.com.cn

# For PostgreSQL - Enable postgresql logs
# aws rds modify-db-instance \
#   --db-instance-identifier $RDS_INSTANCE_ID \
#   --cloudwatch-logs-export-configuration LogTypesToEnable=postgresql \
#   --apply-immediately \
#   --region $REGION_BEIJING

# Wait for modification to complete and verify
aws rds describe-db-instances \
  --db-instance-identifier $RDS_INSTANCE_ID \
  --region $REGION_BEIJING \
  --endpoint-url https://rds.$REGION_BEIJING.amazonaws.com.cn \
  --query 'DBInstances[0].EnabledCloudwatchLogsExports'
```

### Step 9: Create S3 Bucket and Firehose for RDS Logs

```bash
# Create S3 bucket for RDS logs
aws s3api create-bucket \
  --bucket $S3_BUCKET_RDS \
  --region $REGION_NINGXIA \
  --create-bucket-configuration LocationConstraint=$REGION_NINGXIA \
  --endpoint-url https://s3.$REGION_NINGXIA.amazonaws.com.cn

# Create Firehose delivery stream for RDS logs
aws firehose create-delivery-stream \
  --delivery-stream-name rds-logs-to-ningxia \
  --delivery-stream-type DirectPut \
  --s3-destination-configuration '{
    "RoleARN": "arn:aws-cn:iam::'$AWS_ACCOUNT_ID':role/EKSFirehoseDeliveryRole",
    "BucketARN": "arn:aws-cn:s3:::'$S3_BUCKET_RDS'",
    "Prefix": "rds-logs/instance='$RDS_INSTANCE_ID'/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/",
    "ErrorOutputPrefix": "rds-errors/",
    "BufferingHints": {
      "SizeInMBs": 5,
      "IntervalInSeconds": 300
    },
    "CompressionFormat": "GZIP"
  }' \
  --region $REGION_BEIJING \
  --endpoint-url https://firehose.$REGION_BEIJING.amazonaws.com.cn
```

### Step 10: Create Subscription Filters for RDS Logs

```bash
# Wait for RDS log groups to be created (this might take a few minutes)
echo "Waiting for RDS log groups to be created..."
sleep 300

# List available RDS log groups to confirm they exist
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/rds/instance/$RDS_INSTANCE_ID" \
  --region $REGION_BEIJING \
  --endpoint-url https://logs.$REGION_BEIJING.amazonaws.com.cn

# Create subscription filters for each RDS log type
declare -a RDS_LOG_TYPES=("error" "general" "slowquery")

for LOG_TYPE in "${RDS_LOG_TYPES[@]}"
do
  LOG_GROUP_NAME="/aws/rds/instance/$RDS_INSTANCE_ID/$LOG_TYPE"
  FILTER_NAME="RDS${LOG_TYPE^}LogsToFirehose"
  
  echo "Creating subscription filter for $LOG_GROUP_NAME"
  
  # Set retention policy first
  aws logs put-retention-policy \
    --log-group-name "$LOG_GROUP_NAME" \
    --retention-in-days 7 \
    --region $REGION_BEIJING \
    --endpoint-url https://logs.$REGION_BEIJING.amazonaws.com.cn
  
  # Create subscription filter
  aws logs put-subscription-filter \
    --log-group-name "$LOG_GROUP_NAME" \
    --filter-name "$FILTER_NAME" \
    --filter-pattern "" \
    --destination-arn "arn:aws-cn:firehose:$REGION_BEIJING:$AWS_ACCOUNT_ID:deliverystream/rds-logs-to-ningxia" \
    --region $REGION_BEIJING \
    --endpoint-url https://logs.$REGION_BEIJING.amazonaws.com.cn
done
```

---

## Monitoring and Verification

### Step 11: Create Comprehensive Monitoring

```bash
# Create CloudWatch alarms for EKS log delivery
aws cloudwatch put-metric-alarm \
  --alarm-name "EKS-Firehose-Delivery-Failures" \
  --alarm-description "Monitor EKS log delivery failures to Ningxia" \
  --metric-name "DeliveryToS3.Records" \
  --namespace "AWS/Kinesis/Firehose" \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=DeliveryStreamName,Value=eks-logs-to-ningxia \
  --alarm-actions arn:aws-cn:sns:$REGION_BEIJING:$AWS_ACCOUNT_ID:your-sns-topic \
  --region $REGION_BEIJING \
  --endpoint-url https://monitoring.$REGION_BEIJING.amazonaws.com.cn

# Create alarm for RDS log delivery
aws cloudwatch put-metric-alarm \
  --alarm-name "RDS-Firehose-Delivery-Failures" \
  --alarm-description "Monitor RDS log delivery failures to Ningxia" \
  --metric-name "DeliveryToS3.Records" \
  --namespace "AWS/Kinesis/Firehose" \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --dimensions Name=DeliveryStreamName,Value=rds-logs-to-ningxia \
  --region $REGION_BEIJING
```

### Step 12: Verification Steps

```bash
# 1. Check CloudWatch Agent is running on all nodes
kubectl get pods -n amazon-cloudwatch -l name=cloudwatch-agent -o wide

# 2. Check Fluent Bit is running on all nodes
kubectl get pods -n amazon-cloudwatch -l k8s-app=fluent-bit -o wide

# 3. Verify log groups have data
echo "Checking EKS log groups for data..."
for LOG_GROUP in "${LOG_GROUPS[@]}"
do
  echo "Checking: $LOG_GROUP"
  aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --region $REGION_BEIJING \
    --endpoint-url https://logs.$REGION_BEIJING.amazonaws.com.cn \
    --query 'logStreams[0].lastEventTime'
done

# 4. Check Firehose stream status
aws firehose describe-delivery-stream \
  --delivery-stream-name eks-logs-to-ningxia \
  --region $REGION_BEIJING \
  --endpoint-url https://firehose.$REGION_BEIJING.amazonaws.com.cn \
  --query 'DeliveryStreamDescription.DeliveryStreamStatus'

# 5. Check S3 buckets for log files (wait 5-10 minutes after setup)
echo "Checking S3 buckets for log files..."
aws s3 ls s3://$S3_BUCKET_EKS/eks-logs/ --recursive \
  --endpoint-url https://s3.$REGION_NINGXIA.amazonaws.com.cn

aws s3 ls s3://$S3_BUCKET_RDS/rds-logs/ --recursive \
  --endpoint-url https://s3.$REGION_NINGXIA.amazonaws.com.cn

# 6. Test log generation
echo "Generating test log entries..."
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh -c 'echo "Test log entry from EKS pod" && sleep 10'
```

---

## Cost Optimization and Lifecycle Management

### Step 13: Configure S3 Lifecycle Policies

```bash
# Create lifecycle policy for EKS logs
cat > eks-s3-lifecycle.json << EOF
{
  "Rules": [
    {
      "ID": "EKSLogArchivingRule",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "eks-logs/"
      },
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        },
        {
          "Days": 365,
          "StorageClass": "DEEP_ARCHIVE"
        }
      ],
      "Expiration": {
        "Days": 2555
      }
    }
  ]
}
EOF

# Apply lifecycle policy
aws s3api put-bucket-lifecycle-configuration \
  --bucket $S3_BUCKET_EKS \
  --lifecycle-configuration file://eks-s3-lifecycle.json \
  --endpoint-url https://s3.$REGION_NINGXIA.amazonaws.com.cn

# Create similar policy for RDS logs
cat > rds-s3-lifecycle.json << EOF
{
  "Rules": [
    {
      "ID": "RDSLogArchivingRule", 
      "Status": "Enabled",
      "Filter": {
        "Prefix": "rds-logs/"
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
      ],
      "Expiration": {
        "Days": 1095
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket $S3_BUCKET_RDS \
  --lifecycle-configuration file://rds-s3-lifecycle.json \
  --endpoint-url https://s3.$REGION_NINGXIA.amazonaws.com.cn
```

---

## Troubleshooting Common Issues

### Issue 1: CloudWatch Agent Not Starting
```bash
# Check agent status on nodes
kubectl logs -n amazon-cloudwatch -l name=cloudwatch-agent --tail=100

# Check IAM permissions
aws iam list-attached-role-policies --role-name $EKS_NODE_ROLE

# Restart agent
kubectl delete pods -n amazon-cloudwatch -l name=cloudwatch-agent
```

### Issue 2: No Logs in CloudWatch
```bash
# Check if log files exist on nodes
kubectl exec -n amazon-cloudwatch $(kubectl get pods -n amazon-cloudwatch -l name=cloudwatch-agent -o jsonpath='{.items[0].metadata.name}') -- ls -la /var/log/

# Verify agent configuration
kubectl describe configmap cwagentconfig -n amazon-cloudwatch
```

### Issue 3: Firehose Delivery Failures
```bash
# Check Firehose metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kinesis/Firehose \
  --metric-name DeliveryToS3.Success \
  --dimensions Name=DeliveryStreamName,Value=eks-logs-to-ningxia \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region $REGION_BEIJING

# Check error logs
aws logs filter-log-events \
  --log-group-name /aws/kinesisfirehose/eks-logs-to-ningxia \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --region $REGION_BEIJING
```

This comprehensive guide provides all the specific steps needed to implement EKS log backup from Beijing to Ningxia region in AWS China, including node-level logs, container logs, and database logs with proper monitoring and cost optimization.
