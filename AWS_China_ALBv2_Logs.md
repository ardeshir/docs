## AWS CLI Command for China Regions

```bash
aws elbv2 modify-load-balancer-attributes \
    --load-balancer-arn <your-alb-arn> \
    --attributes \
        Key=access_logs.s3.enabled,Value=true \
        Key=access_logs.s3.bucket,Value=<your-s3-bucket-name> \
        Key=access_logs.s3.prefix,Value=<optional-prefix>
```

## S3 Bucket Policy for AWS China

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws-cn:iam::<elb-account-id>:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws-cn:s3:::<your-bucket-name>/<prefix>/*"
    }
  ]
}
```

## ELB Service Account IDs for China Regions

- **Beijing (cn-north-1)**: 638102146993
- **Ningxia (cn-northwest-1)**: 037604701340

## Complete Example for Beijing (cn-north-1)

```bash
# First, get your ALB ARN if you don't have it
aws elbv2 describe-load-balancers --names <your-alb-name> --region cn-north-1

# Then enable logging
aws elbv2 modify-load-balancer-attributes \
    --load-balancer-arn arn:aws-cn:elasticloadbalancing:cn-north-1:123456789012:loadbalancer/app/my-alb/50dc6c495c0c9188 \
    --attributes \
        Key=access_logs.s3.enabled,Value=true \
        Key=access_logs.s3.bucket,Value=my-alb-logs-bucket \
        Key=access_logs.s3.prefix,Value=eks-alb-logs \
    --region cn-north-1
```

## S3 Bucket Policy Example for Beijing

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws-cn:iam::638102146993:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws-cn:s3:::my-alb-logs-bucket/eks-alb-logs/*"
    }
  ]
}
```

## S3 Bucket Policy Example for Ningxia

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws-cn:iam::037604701340:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws-cn:s3:::my-alb-logs-bucket/eks-alb-logs/*"
    }
  ]
}
```

## Verify the Configuration

```bash
aws elbv2 describe-load-balancer-attributes \
    --load-balancer-arn <your-alb-arn> \
    --query "Attributes[?Key=='access_logs.s3.enabled']" \
    --region cn-north-1
```

## Important Notes for AWS China

1. Ensure you're using the AWS China CLI credentials and endpoints
2. The `--region` parameter should be either `cn-north-1` or `cn-northwest-1`
3. All ARNs must use the `aws-cn` partition instead of `aws`
4. The S3 bucket must be in the same China region as your ALB

This should properly enable ALB access logging for your EKS load balancers in AWS China regions.
