# Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the AWS Cloud Migration & SLO Implementation solution. The deployment process is fully automated and follows enterprise-level best practices.

## Prerequisites

### Required Tools
- AWS CLI >= 2.0
- Terraform >= 1.0
- Docker >= 20.0
- Python 3.8+ (for SLO verification)
- Git

### AWS Permissions
Ensure your AWS credentials have the following permissions:
- EC2, ECS, ELB, VPC management
- IAM role creation and management
- CloudWatch, SNS, SES access
- S3 bucket creation and management
- Secrets Manager access
- WAF, Config, GuardDuty management

### Environment Setup
```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity

# Clone the repository
git clone <repository-url>
cd aws-cloud-migration-slo-ecs
```

## Deployment Process

### 1. Initial Setup

Create the Terraform state bucket (one-time setup):

```bash
# Replace with your desired bucket name
BUCKET_NAME="your-terraform-state-bucket"
REGION="us-west-2"

aws s3 mb s3://$BUCKET_NAME --region $REGION
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption \
    --bucket $BUCKET_NAME \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'
```

### 2. Development Environment

Deploy to development environment:

```bash
# Validate configuration
./scripts/deploy.sh -v

# Deploy to development
./scripts/deploy.sh -e dev

# Check deployment status
./scripts/deploy.sh -e dev -p  # Plan only
```

### 3. Staging Environment

Deploy to staging environment:

```bash
# Build and deploy to staging
./scripts/deploy.sh -e staging

# Verify SLO compliance
python3 scripts/verify-slo.py --environment staging
```

### 4. Production Environment

Deploy to production environment with extra precautions:

```bash
# Plan production deployment
./scripts/deploy.sh -e prod -p

# Deploy to production (requires confirmation)
./scripts/deploy.sh -e prod

# Verify SLO compliance
python3 scripts/verify-slo.py --environment prod
```

## Environment-Specific Configurations

### Development
- Minimal resources for cost optimization
- Reduced monitoring frequency
- Simplified security settings
- No cross-region backup

### Staging
- Production-like configuration
- Full monitoring and alerting
- Security features enabled
- Load testing capabilities

### Production
- High availability setup
- Maximum security configurations
- Full compliance monitoring
- Cross-region backup enabled
- Shield Advanced protection

## Post-Deployment Verification

### 1. Health Checks
```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names dotnet-migration-prod-alb \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

# Test health endpoint
curl https://$ALB_DNS/health

# Test API endpoint
curl https://$ALB_DNS/api/weather
```

### 2. SLO Monitoring
Access CloudWatch dashboards:
- Main SLO Dashboard: `dotnet-migration-{env}-slo-dashboard`
- SLO Tracking Dashboard: `dotnet-migration-{env}-slo-tracking`

### 3. Security Verification
```bash
# Check WAF status
aws wafv2 list-web-acls --scope REGIONAL

# Check GuardDuty findings
aws guardduty list-findings --detector-id <detector-id>

# Check Security Hub findings
aws securityhub get-findings
```

## Rollback Procedures

### Application Rollback
```bash
# Revert to previous image
./scripts/deploy.sh -e prod -i <previous-image-uri>
```

### Infrastructure Rollback
```bash
# Revert to previous Terraform state
cd terraform/environments/prod
terraform plan -target=<resource> -destroy
terraform apply
```

### Emergency Procedures
1. Scale down to zero instances: Set desired count to 0
2. Route traffic to maintenance page via Route 53
3. Restore from backup if database changes were made

## Monitoring and Alerting

### CloudWatch Dashboards
- **SLO Dashboard**: Real-time SLO metrics
- **Application Dashboard**: Application-specific metrics
- **Infrastructure Dashboard**: ECS, ALB, and VPC metrics

### Alerts Configuration
Alerts are automatically configured for:
- SLO violations (availability < 99.95%)
- High latency (P95 > 500ms)
- Error rate (> 0.1%)
- Infrastructure issues (high CPU/memory)

### SLO Targets
| Metric | Target | Measurement Window |
|--------|--------|--------------------|
| Availability | 99.95% | 30-day rolling |
| Latency (P95) | < 500ms | 5-minute windows |
| Error Rate | < 0.1% | 5-minute windows |

## Troubleshooting

### Common Issues

#### Deployment Failures
```bash
# Check Terraform logs
cd terraform/environments/<env>
terraform plan -detailed-exitcode

# Check ECS service status
aws ecs describe-services --cluster <cluster-name> --services <service-name>
```

#### Application Issues
```bash
# Check ECS task logs
aws logs tail /ecs/dotnet-migration-<env>/dotnet-app --follow

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

#### SLO Violations
1. Check CloudWatch Synthetics canary results
2. Review ALB access logs in S3
3. Analyze ECS service metrics
4. Check for AWS service issues

### Recovery Procedures

#### Service Recovery
```bash
# Force new deployment
aws ecs update-service \
    --cluster <cluster-name> \
    --service <service-name> \
    --force-new-deployment
```

#### Database Recovery
```bash
# Restore from backup (if RDS enabled)
aws rds restore-db-instance-from-db-snapshot \
    --db-instance-identifier <new-instance-id> \
    --db-snapshot-identifier <snapshot-id>
```

## Cost Optimization

### Regular Reviews
- Monitor AWS Cost Explorer monthly
- Review Reserved Instance recommendations
- Analyze ECS task right-sizing opportunities
- Optimize CloudWatch log retention

### Automated Cost Controls
- Budget alerts configured
- Auto-scaling policies prevent over-provisioning
- S3 lifecycle policies for log archival
- Spot instances for non-production workloads

## Security Best Practices

### Implemented Security Measures
- VPC with private subnets
- WAF with managed rule sets
- Security groups with minimal access
- IAM roles with least privilege
- Secrets Manager for sensitive data
- Encryption at rest and in transit

### Regular Security Tasks
- Review GuardDuty findings weekly
- Update WAF rules based on threat intelligence
- Rotate secrets quarterly
- Review Security Hub compliance scores
- Conduct security assessments

## Support and Maintenance

### Regular Maintenance Windows
- **Development**: No scheduled maintenance
- **Staging**: Sundays 02:00-04:00 UTC
- **Production**: First Sunday of month 02:00-04:00 UTC

### Emergency Contacts
- Platform Team: platform-team@company.com
- On-call Engineer: +1-XXX-XXX-XXXX
- Incident Response: incidents@company.com

### Documentation Updates
This guide should be updated whenever:
- New features are deployed
- Configuration changes are made
- Security policies are updated
- Incident response procedures change
